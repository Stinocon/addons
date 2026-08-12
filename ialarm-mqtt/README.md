# Home Assistant Add-on: iAlarm MQTT Bridge (Enhanced)

🚀 **Enhanced iAlarm MQTT integration with critical bug fixes and clean entity naming.**

This add-on allows you to control iAlarm systems (antifurtocasa365, Emooluxr, Casasicura and other Meian/Focus clones) via the enhanced ialarm-mqtt library with professional entity naming and bug fixes.

## 🔧 Enhanced Features

This enhanced version includes **critical fixes and improvements** over the original:

- ✅ **Fixed bugs #45 and #51** - Entity name flip-flop and HA 2024.2+ compliance
- ✅ **Clean entity naming** - No more ugly _2, _3, _4 suffixes (e.g., "Cantina", "Cantina Stato", "Cantina Batteria")
- ✅ **MQTT prefix `ialarm-v2`** (vs `ialarm` in original)
- ✅ **Unique device identifiers** - No Home Assistant entity conflicts
- ✅ **Enhanced logging** and discovery management
- ✅ **Professional branding** - Antifurto365 manufacturer with customizable naming
- ✅ **Configurable arm modes** - `supportedFeatures` (default Home/Away) hides the unused Night/Vacation/Custom-bypass buttons
- ✅ **Zone ID indicators** - optional `zoneId` feature: a per-zone "Zone ID" sensor plus a global `id → name` directory sensor for automations

> ⚠️ **Disclaimer — "vibecoded".** The enhancements and fixes listed above were *vibecoded*:
> developed with AI assistance rather than hand-written by a maintainer with deep knowledge
> of the codebase. They are tested as documented and work for the maintainer's setup, but use them
> at your own risk.

## ⚠️ Important Connection Limitation

**IMPORTANT:** The iAlarm central unit allows only **one connection at a time**. You cannot run both the original and this enhanced version simultaneously.

**However,** this enhanced version provides better configuration options and can replace the original addon:

```yaml
branding:
  prefix: "ialarm-v2"              # MQTT topic prefix (vs "ialarm" in original)
  uniqueIdSuffix: "_ialarmv2"      # Prevents HA entity conflicts  
  deviceNameSuffix: " (Enhanced)"  # UI clarity
  manufacturer: "Antifurto365"     # Custom manufacturer
```

**Result:** Your devices will appear as "iAlarm Security Panel (Enhanced)" with topics under `ialarm-v2/*` and clean entity names.

## Compatible Models

Some compatible alarm system models:
* ST-IVCGT
* Antifurtocasa365 panels
* Emooluxr systems
* Casasicura alarms
* Other Meian/Focus clones

## Features

* **Arm home** - Set home/stay mode
* **Arm away** - Set away mode  
* **Disarm** - Disarm the system
* **Zone monitoring** - Real-time status (ok/problem, open, alarm, bypass, fault, low battery, signal loss)
* **Home Assistant MQTT Discovery** - Automatic entity creation
* **Multi-area support** - Handle multiple alarm areas
* **Zone customization** - Configure specific zones with custom device classes

> **Note:** To obtain 'open' property in real-time, enable "DoorDetect" ("Ispezione sensori porta" in Italian panels) in your alarm web panel options (`http://192.168.1.x/Option.htm`).

## Basic Configuration

Configure your alarm system connection and MQTT broker:

```yaml
name: "My Alarm System" # Optional custom name
server:
  host: 192.168.1.81     # Alarm panel IP address
  port: 18034            # Default TCP port
  username: admin        # Panel username
  password: password     # Panel password
  zones:                 # Zones to monitor (array format)
    - 1
    - 2
    - 3
    - 4
    - 5
    - 6
    # Add more zones as needed (up to 40)
  polling_status: 5000   # Status polling interval (milliseconds)
  features:              # Which entity groups to publish
    - armDisarm
    - sensors
    - events
    - bypass
    - zoneNames
    - zoneId             # Zone ID sensor + id->name directory (see below)

mqtt:
  host: 192.168.1.82     # MQTT broker IP
  port: 1883             # MQTT broker port
  username: admin        # MQTT username
  password: password     # MQTT password
  clientId: ialarm-mqtt  # MQTT client ID
  cache: 5m              # Send updates only on change or every 5 minutes
  retain: true           # Use MQTT retain flag

hadiscovery:
  alarm_qos: 2           # QoS for alarm topics
  sensors_qos: 0         # QoS for sensor topics
  code: "1234"           # Optional: 4-digit HA frontend code
  zoneName: "Zone"       # Zone name prefix
  supportedFeatures:     # Arm modes shown by the HA alarm panel (disarm is always available)
    - arm_home
    - arm_away

# Advanced zone configuration (optional)
zones:
  - number: 39
    contactType: NO      # NO=normally open, NC=normally closed
    device_class: moisture # HA device class (door, window, motion, etc.)
    statusProperty: open # Property to monitor (fault, open, alarm, etc.)
```

## Advanced Configuration

### Home Assistant Frontend Code

Set a 4-digit code to arm/disarm via HA frontend:

```yaml
hadiscovery:
  code: "1234"
```

### Custom Zone Configuration

Configure specific zones with custom behavior:

```yaml
zones:
  - number: 1
    contactType: NC
    device_class: door
    statusProperty: fault
  - number: 2
    contactType: NO
    device_class: moisture
    statusProperty: open
```

**Device Classes:** Use any [Home Assistant device class](https://www.home-assistant.io/integrations/binary_sensor/#device-class) like:
- `door`, `window`, `garage_door`
- `motion`, `occupancy`
- `smoke`, `gas`, `safety`
- `moisture`, `problem`

### Features list

The `server.features` option controls which groups of entities the add-on publishes.
All are enabled by default. Remove any you don't want.

| Feature | What it does |
|---------|--------------|
| `armDisarm` | The `alarm_control_panel` entity (arm/disarm) and the "cancel triggered" switch |
| `sensors` | Per-zone binary sensors: state/fault, alarm, battery, connectivity |
| `events` | The "last event" sensor (requires panel push events) |
| `bypass` | Per-zone bypass switches |
| `zoneNames` | Fetch real zone names from the panel (`GetZone`); if disabled, generic names are used |
| `zoneId` | Per-zone **Zone ID** diagnostic sensor + global **zone directory** sensor (see below) |

```yaml
server:
  features:
    - armDisarm
    - sensors
    - events
    - bypass
    - zoneNames
    - zoneId
```

### Arm modes (supported_features)

By default Home Assistant shows every arm button (Home, Away, Night, Vacation, Custom bypass).
This add-on only implements Home and Away, so it advertises just those via `supportedFeatures`.
Override it to expose more/fewer buttons (allowed values: `arm_home`, `arm_away`, `arm_night`,
`arm_vacation`, `arm_custom_bypass`, `trigger`). Disarm is always available.

```yaml
hadiscovery:
  supportedFeatures:
    - arm_home
    - arm_away
```

### Zone ID indicators (`zoneId` feature)

Add `zoneId` to the `features` list to map a panel zone number to a room in HA:

- **Per-zone Zone ID sensor** — a diagnostic sensor on each zone device showing the panel zone
  id (e.g. `6`). Useful when the panel/app reports "zone 6 open" and you want to know the room.
- **Zone directory sensor** — a diagnostic sensor on the alarm device whose state is the number
  of zones and whose attributes contain the full `id → name` map. Published (retained) to
  `{prefix}/zones/directory`. Ideal for automations, e.g. notifying which open zone is blocking
  arming.

```yaml
server:
  features:
    - armDisarm
    - sensors
    - events
    - bypass
    - zoneNames
    - zoneId
```

These entities are additive and reuse data already on MQTT — enabling/disabling the feature
does not affect your other entities or their manual renames.

These sensors ship with clean default entity IDs, e.g. `sensor.<zone>_ialarm_id_zona` and
`sensor.ialarm_zone_directory`. Home Assistant only applies a default entity ID when an entity
is **first created**, so if you enabled `zoneId` on an earlier version and got long auto-generated
IDs, delete those entities (or their device) once — they will be recreated with the clean IDs on
the next discovery.

## 🔗 Documentation & Support

- **Configuration:** see this README (fork-specific options) and the [`CHANGELOG.md`](CHANGELOG.md)
- **Enhanced Source Code:** https://github.com/Stinocon/ialarm-mqtt
- **Add-on Repository:** https://github.com/Stinocon/addons
- **Original project (general reference):** https://github.com/maxill1/ialarm-mqtt — including its [Configuration](https://github.com/maxill1/ialarm-mqtt/wiki/Configuration) and [Troubleshooting](https://github.com/maxill1/ialarm-mqtt/wiki/Troubleshooting) wiki pages (these predate this fork's enhancements)

**Where to report what:** problems installing, configuring or starting the add-on go to
[this repository's issues](https://github.com/Stinocon/addons/issues); problems with entities,
MQTT discovery or panel communication go to
[Stinocon/ialarm-mqtt](https://github.com/Stinocon/ialarm-mqtt/issues).

## Important Notes

- **TCP Implementation:** Since version 2.0, this addon uses TCP implementation. Ensure port is set to `18034` (not `80`)
- **Zone Limit:** Maximum 40 zones supported per alarm panel
- **Enhanced Features:** This version provides clean entity naming and bug fixes over the original
- **Version Alignment:** Addon versions are aligned with the underlying ialarm-mqtt library

## Migration from Original

If migrating from the original addon:

1. **Single connection:** The iAlarm central unit allows only one connection at a time
2. **Replace original:** Stop the original addon before starting this enhanced version
3. **Configuration compatibility:** Same configuration format with enhanced branding defaults
4. **Clean entities:** This version will generate clean entity names without ugly suffixes

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and recent improvements.

## Licence

The packaging in this directory — `config.yaml`, `Dockerfile`, `build.yaml`, `rootfs/`, the
documentation and the artwork — is original work under the repository's
[`LICENSE`](../LICENSE), MIT.

The application it installs is not: [Stinocon/ialarm-mqtt](https://github.com/Stinocon/ialarm-mqtt),
a fork of [maxill1/ialarm-mqtt](https://github.com/maxill1/ialarm-mqtt), **MIT © 2019 Luca
Mazzilli**. That notice ships with every image built here, because MIT requires it to travel
with the software. Full detail in [`NOTICE.md`](../NOTICE.md).