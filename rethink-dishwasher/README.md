# rethink-cloud — LG Dishwasher

A Home Assistant add-on packaging of [rethink](https://github.com/anszom/rethink) — a local
reimplementation of LG's ThinQ cloud — extended with support for **LG ThinQ dishwashers**
(model `D0211`, deviceType 204; sold as DB365TXS / DBC435TSL and similar).

With this add-on your LG dishwasher talks to Home Assistant **directly**, with no LG cloud and
no LG app. State, program, remaining time, cycle end, errors and the salt / rinse-aid refill
indicators all land on MQTT, from which Home Assistant auto-discovers them.

> **Status — dishwasher support is a scaffold.** The dishwasher model is registered and the
> target entities are exposed, but the field decoding is still being written against live
> captures. The rest of rethink (ACs, washers, dryers, fridges, hoods, …) works as upstream.

## How it works

LG ThinQ appliances expose no local protocol: their Wi-Fi module dials out to LG's servers over
TLS/MQTT. rethink **replaces that server locally**. You provision the appliance once so it
connects to the add-on instead of LG, and from then on its traffic stays on your LAN.

Two modes of the same server:

- **Local only** — the appliance talks only to the add-on; nothing leaves the house. This is
  the goal.
- **Bridge** — the add-on additionally forwards every message to the real LG cloud, so the
  official app keeps working. Useful during reverse-engineering, or if you still want the app.

## Install

1. Add this repository to Home Assistant:
   **Settings → Add-ons → Add-on Store → ⋮ → Repositories** →
   `https://github.com/Stinocon/addons`
2. Install **"rethink-cloud — LG Dishwasher"**.
3. Configure the options (below), then start the add-on.
4. Provision your appliance once (see [Provisioning](#provisioning)).

## Configuration

| Option | Default | Notes |
| --- | --- | --- |
| `hostname` | `rethink.lan` | The name the appliance is told to connect to. **Must be a real DNS name the appliance can resolve — not mDNS / `.local`** (the modem has no mDNS resolver). Add a static DNS entry on your router. |
| `mqtt_url` | `mqtt://localhost:1883` | Where rethink publishes state for Home Assistant (the Mosquitto add-on). |
| `mqtt_user` / `mqtt_pass` | empty | Mosquitto credentials, if you enabled auth. |
| `https_port` | `4433` | HTTPS the appliance bootstraps against. Set `443` if that port is free on your HA host; otherwise keep `4433` and add the one-time redirect below. |
| `mqtts_port` | `18884` | MQTT-over-TLS the appliance talks to. `18884` (not upstream's `8884`) avoids colliding with Mosquitto's host ports. |
| `mqtt_port` | `1885` | Plain MQTT. `1885` avoids Mosquitto's `1884`. |
| `management_port` | `44401` | The web UI (device list, bridge toggle, capture). |
| `log_level` | `status, incoming, HTTPS, publish, MGMT` | Server log categories. |

Ports are options rather than network mappings: on `host_network` this add-on reads
`/data/options.json` directly (no Supervisor API), and each port is used both to bind **and** to
advertise to the appliance.

## Provisioning

One-time, at-your-own-risk (the modem does not fully clear settings on reconfigure; it is
reversible by re-registering with the LG app). You need the `rethink` source checked out on a
computer that can join the appliance's Wi-Fi access point, and `node` + `npm` on it.

1. **Point the bootstrap hostname at the add-on.** The appliance dials `common.lgthinq.com:443`
   on first setup, before it knows the add-on's own hostname. During setup only, make that name
   land on the add-on. See [Mikrotik rules](#mikrotik-rules-routeros) for the exact recipe.
2. **Put the appliance in Wi-Fi setup mode.** For the dishwasher: hold **Delay Start** for ~3 s
   until the Wi-Fi LED blinks. The appliance opens an access point (observed:
   `LG_Smart_DishWasher2_open`, open network — the LG quick-start guide's "password = last 4
   digits ×2" does **not** apply to this model).
3. **Run `rethink-setup`** from a computer joined to that access point:
   ```bash
   npx tsx rethink-setup.ts 192.168.120.254 "<home-ssid>" "<home-wifi-password>"
   ```
   It tries ThinQ1 then ThinQ2 automatically. On success the add-on log shows the ThinQ2
   provisioning (`/route`, `clip/provisioning/devices/…`) and the device appears in the
   management UI.
4. **Remove the temporary bootstrap redirect** now (the appliance caches the add-on's real
   address and no longer needs it — and the bridge's outbound leg needs the real
   `common.lgthinq.com` back).

### Mikrotik rules (RouterOS)

The bootstrap redirect has a subtlety when the appliance and Home Assistant are on the **same
VLAN**: their traffic is layer-2 and never traverses the router, so a plain DNAT to the HA host
would never be seen. The fix is to point the DNS at the **router's own VLAN gateway** so the
router is in the path, then DNAT + hairpin masquerade to the add-on. On a firewalled install
you also need to let the DNAT'd traffic through the forward chain.

Substitute your real values for the placeholders:

```routeros
# 1. During setup only: resolve the bootstrap name to the router's own VLAN gateway
#    (NOT the HA host — see the same-VLAN note above).
/ip dns static add name=common.lgthinq.com address=<router-vlan-gateway> type=A comment=rethink-bootstrap

# 2. DNAT 443 -> add-on HTTPS port (4433 when 443 is taken by HA's own TLS).
/ip firewall nat add chain=dstnat dst-address=<router-vlan-gateway> dst-port=443 protocol=tcp \
    action=dst-nat to-addresses=<ha-host> to-ports=4433 comment=rethink-bootstrap

# 3. Hairpin masquerade: make the reply come back through the router instead of going L2
#    straight from HA to the appliance (which would be an asymmetric reply the appliance drops).
/ip firewall nat add chain=srcnat src-address=<appliance-vlan-subnet> dst-address=<ha-host> \
    dst-port=4433 protocol=tcp action=masquerade comment=rethink-bootstrap

# 4. Only needed when a forward rule drops intra-VLAN traffic (e.g. a "deny VLAN-X to all"
#    client-isolation rule). Accept the DNAT'd bootstrap before that drop rule.
#    `place-before` targets the drop rule's number — adjust to your install.
/ip firewall filter add chain=forward action=accept connection-nat-state=dstnat \
    in-interface=<appliance-vlan> comment=rethink-bootstrap place-before=<drop-rule-number>
```

Remove all four after the appliance is provisioned:

```routeros
/ip dns static remove [find name=common.lgthinq.com]
/ip firewall nat remove [find comment=rethink-bootstrap]
/ip firewall filter remove [find comment=rethink-bootstrap]
```

Why remove: the appliance now talks to `hostname` directly, and the **bridge's** outbound
connection to the real `common.lgthinq.com` must not loop back through the redirect.

## Bridge mode (optional)

To keep the LG app working (or to correlate raw captures with the cloud's decoded view):

1. Open the management UI (`http://<ha-host>:44401`) → **"Log into your LG account"**, country
   code matching your account.
2. Toggle **Bridge** for the device and enter its `deviceType` (**204** for the dishwasher).
3. Open the LG app to confirm it still sees the appliance.

The LG login is the standard ThinQ OAuth; your credentials go only to LG. The token is stored
under `/data/state/` (persistent, excluded from backups).

## Capturing raw traffic

With the device in the management UI, record the live wire traffic locally:

```bash
npx tsx tools/rethink-capture.ts <ha-host>:44401 <device-id> capture.jsonl
```

Add `--cloud --state oauth.json` to also record the LG cloud's decoded interpretation alongside
the raw frames.

## Security

- **`host_network: true`** — required (see the port invariant). The add-on binds a handful of
  ports on the host; keep the management UI off anything internet-facing.
- The management UI has **no authentication**. It is meant for a trusted LAN.
- The CA private key (`/data/ca.key`) is the trust anchor the appliance was provisioned with;
  **preserve `/data` across add-on rebuilds** or the appliance must be re-provisioned.

## License

The add-on packaging in this repository is MIT. The server it builds is
[rethink](https://github.com/anszom/rethink) (GPL), vendored at build time from
[Stinocon/rethink-dishwasher](https://github.com/Stinocon/rethink-dishwasher), a GPL fork that
adds the dishwasher definition.
