# SBFspot MQTT Bridge

Reads an SMA Sunny Boy inverter over **Bluetooth** and publishes it to Home Assistant over MQTT
discovery.

## What it is for

Legacy SMA inverters — a Sunny Boy with an SMA Bluetooth Piggy-Back, or the models with
integrated Bluetooth — have no network interface at all. They answer over Bluetooth, and only to
**one master at a time**: Sunny Explorer, a Sunny Beam, a Webbox, or this add-on, never two of
them at once.

This add-on runs [sbfspot-mqtt](https://github.com/Stinocon/sbfspot-mqtt), which polls such an
inverter with [SBFspot](https://github.com/SBFspot/SBFspot) — on a 60-second interval by default,
timed from the end of one reading to the start of the next — and publishes what comes back as Home Assistant entities: current
power, energy today and total, status, temperature, DC voltage/current per string, grid frequency,
operating hours.

It is **read-only**. Nothing here writes to the inverter — not a setting, not a command, and not
the clock: `-settime` is never passed, and the generated configuration sets `SynchTime=0`, because
upstream's default of 1 rewrites the plant clock over Bluetooth on *every* poll.

## Requirements

- **Home Assistant OS**, on `aarch64` or `amd64`. Not a Home Assistant Container: the add-on
  relies on the Supervisor for the MQTT broker's address and credentials.
- An **MQTT broker**. The Mosquitto add-on is found automatically; a broker elsewhere can be
  configured below.
- An SMA inverter with Bluetooth, **in range of the machine running Home Assistant** — the radio
  is the one built into that machine, and walls matter.
- The inverter's **Bluetooth address** and its **user password**.
- **Every other Bluetooth master switched off.** If the Sunny Beam is still on its shelf polling
  the inverter, this add-on gets nothing but failed connections: the inverter answers one master,
  and while the Beam holds the connection, that master is not this add-on.

## Installation

In Home Assistant: **Settings → Add-ons → Add-on Store**, top-right menu, **Repositories**, add:

```
https://github.com/Stinocon/addons
```

Then install **SBFspot MQTT bridge**, fill in `bt_address` and `password`, and start it.

### Finding the Bluetooth address

Any of these work, in order of convenience:

- **Sunny Explorer**, connected to the inverter: the address is in the device information.
- On a Linux machine in range: `bluetoothctl scan on` (the inverter appears as a device named
  after its serial).

The Sunny Beam shows the plant's NetID and its own Bluetooth version, not this address.

## Configuration

| Option | Default | What it does |
|--------|---------|--------------|
| `bt_address` | *(empty)* | The inverter's Bluetooth address, `AA:BB:CC:DD:EE:FF`. Left empty the add-on stops at startup and says so, rather than connecting to whatever answers. |
| `password` | `0000` | The inverter's **user** password, not the installer one. `0000` is SMA's default; if it was changed in Sunny Explorer, this has to match. |
| `plantname` | `MyPlant` | A label for the plant. It appears in the log and in the installer's own configuration summary. It must not contain `'` or `"`, which SBFspot's MQTT command line cannot carry. |
| `interval` | `60` | Seconds between two polls. The minimum is 10. Every poll is a Bluetooth connection to a device that sleeps between them, and the values behind it move on the scale of a minute. |
| `mqtt_host` | *(empty)* | The broker's address. Empty means "the one the Supervisor knows about". |
| `mqtt_port` | `1883` | The broker's port. |
| `mqtt_username` | *(empty)* | Broker credentials, only needed for a broker that is not the Supervisor's. |
| `mqtt_password` | *(empty)* | Same. |
| `log_level` | `info` | `debug` passes `-v5` to SBFspot and prints the full configuration and data dump of every reading. Useful for a diagnosis, unreadable as a permanent setting. The other levels are accepted and behave like `info`: upstream has one switch for this, the quiet flag. |

The MQTT credentials are not stored in the add-on configuration when the broker comes from the
Supervisor: they are read from it at startup, written to `/data/mqtt.json` with mode 600, and
excluded from backups. They are also kept out of SBFspot's publish command, which upstream builds
as a shell string and prints in its log.

They do reach `mosquitto_pub` and `mosquitto_sub` as `-P` arguments — those clients cannot read a
password from a file — and an argument is visible to processes in the same container and to
anything that can read the host's process table. Removing that too would mean shipping a
different MQTT client; this version states it instead of implying otherwise.

## The entities

One device in Home Assistant — named after the inverter, or after its model when nobody named it —
with the sensors the inverter actually reports:

| Sensor | Unit | Notes |
|--------|------|-------|
| Power | W | Instantaneous AC power. |
| Energy today | kWh | Resets at midnight. |
| Energy total | kWh | Lifetime yield — this is the one for the Energy dashboard. |
| Status | — | `Ok`, `Derating`, `Fault`, … as the inverter reports it. Useful as an automation trigger. |
| Temperature | °C | Inverter temperature. |
| DC voltage / current / power, string N | V / A / W | One set per string the inverter reports; an input nobody wired reads zero. |
| Grid frequency | Hz | |
| Operating time, Feed-in time | h | Lifetime counters. |
| Grid relay | — | `Closed` when the inverter is feeding the grid. |
| Inverter time, Data timestamp | — | The clock in the inverter, and when the reading was taken. |

The Grid relay, Inverter time and Data timestamp sensors are published as **diagnostic** entities:
they sit on the device page, out of the way of a dashboard, because they are for troubleshooting
rather than for watching the plant.

Every key in the reading becomes a sensor, with two exceptions: the device identity keys
(`InvSerial`, `InvName`, `InvClass`, `InvType`, `InvSwVer`, `Plantname`) go into the device
registration instead, and a key the add-on has no mapping for is written to the log rather than
invented.

That is also the limit of it, and it is worth saying plainly. The channels *asked for* are a fixed
list in the generated configuration, and SBFspot answers every one of them — with `0` or `?` when
the model has no such channel, and with **every MPPT slot the protocol has**, because upstream
seeds them all before every reading. An inverter that uses one string input therefore reports the
other as 0 V, 0 A and 0 W, on every reading, for as long as the installation exists: that is what an
unused input looks like, not a fault. Naming one slot instead would read a model that reports in the
other one as zeros, so the list stays as wide as the protocol — and the three entities can be
**disabled** in Home Assistant if they are noise on the device page.

If the inverter stops answering, all of them go **unavailable** after three failed polls, rather
than showing a value from an hour ago as if it were current.

### Energy dashboard

**Settings → Dashboards → Energy → Solar production → Add solar production**, and pick
**Energy total**. It carries `device_class: energy`, `state_class: total_increasing` and `kWh`,
which is exactly what the dashboard requires.

## How it works

- Two things are fetched at image build time, each pinned to a tag and never vendored: SBFspot,
  compiled from source (`make nosql` — no database, because Home Assistant already records the
  states and a second one inside the container would be one more thing to back up and explain),
  and [`Stinocon/sbfspot-mqtt`](https://github.com/Stinocon/sbfspot-mqtt), the program that drives
  it. The service scripts here do one thing the program cannot: ask the Supervisor where the MQTT
  broker is.
- Each poll runs `SBFspot -ad0 -am0 -finq -mqtt`: spot data only, no archive read, no CSV export,
  no database. The program receives the reading through SBFspot's own publisher hook, refuses
  anything that is not a valid JSON object instead of publishing a truncated payload as a sensor
  that never updates again, and repairs the one corruption upstream produces on its own — an empty
  string value, which is what an inverter nobody named in Sunny Explorer has.
- The broker's address and credentials come from the Supervisor's MQTT service when the options
  leave them empty, and reach the publisher from a mode-600 file rather than through the shell
  string SBFspot builds.
- Discovery is published once, retained, from the first successful reading, and republished when
  the set of keys changes — a second string waking up, a firmware update. It is also re-published
  at every start, so a changed sensor definition takes effect. A channel that stops appearing is
  **retired**: its configuration is deleted from the broker rather than left describing an entity
  whose value template resolves to nothing.

## Known limitations

- **One inverter.** A second inverter on the same Bluetooth network would publish to the same
  MQTT topic and be indistinguishable from the first. Multi-inverter (`MIS_Enabled`) systems need
  a topic per serial, which this version does not do.
- The values are as fresh as the interval, and no fresher: this is a poll of a device that sleeps.
- An inverter that does not report a channel does not get a sensor for it. Old models report
  fewer, and a missing sensor is not a fault in the add-on.
- The add-on has to run where the Bluetooth reaches the inverter. A Sunny Beam is a Class 1 radio
  that can be placed at a distance; an add-on cannot.

## Troubleshooting

**"Poll failed" every interval.** In order of likelihood: the Sunny Beam (or Sunny Explorer, or a
Webbox) is still connected to the inverter; the address is wrong; the machine is out of range;
the password is wrong. Set `log_level: debug` and SBFspot's own error appears in the log — a
connection that never establishes looks different from one that is refused.

**The entities are all unavailable.** Same causes: three consecutive failed polls publish
`offline` on the availability topic. They return to their values on the next successful poll.

**No entities at all, but the add-on is running.** Discovery is published after the first
successful reading. Until the inverter has answered once, there is nothing to describe.

**"Timezone … is not one of the zones SBFspot knows".** A warning, not a failure. SBFspot
validates the timezone against the boost database, which contains region names and not `UTC`; the
add-on falls back to `Europe/Brussels`, the default upstream ships. It affects nothing this
add-on publishes.

**A version banner in the log on every poll.** Set `log_level` back to `info`: `debug` drops the
quiet flag and passes `-v5`, which is upstream's full configuration and data dump.

## Credits and licence

What does the work is [`Stinocon/sbfspot-mqtt`](https://github.com/Stinocon/sbfspot-mqtt), pinned to
a tag in the `Dockerfile`; it is MIT, and this directory is the packaging around it. The two are
checked against each other in
[`sbfspot-mqtt-ci.yml`](../.github/workflows/sbfspot-mqtt-ci.yml), which clones the pinned tag, runs
that repository's own gate, and re-asserts the subcommands and the option names the service scripts
call — a rename on either side fails there instead of on your machine.

The inverter protocol is [SBFspot](https://github.com/SBFspot/SBFspot)'s work, licensed
**CC BY-NC-SA 3.0** — attribution, non-commercial, share-alike — and compiled from source at image
build time, never forked. [`NOTICE.md`](../NOTICE.md) records what that means for anyone reusing
this.

SMA, Sunny Boy, Sunny Beam, Sunny Explorer and Webbox are registered trademarks of SMA Solar
Technology AG. This add-on is not affiliated with or endorsed by SMA.
