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

## ⚠️ Important Connection Limitation

**IMPORTANT:** The iAlarm central unit allows only **one connection at a time**. You cannot run both the original and this enhanced version simultaneously.

**However,** this enhanced version provides better configuration options and can replace the original addon:

```yaml
branding:
  prefix: "ialarm"                 # MQTT topic prefix (same as original)
  uniqueIdSuffix: ""               # No suffix needed
  deviceNameSuffix: ""             # No suffix needed
  manufacturer: "Meian"            # Original manufacturer
```

**Result:** Your devices will appear as "iAlarm Security Panel" with topics under `ialarm/*` and clean entity names.

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

## 🔗 Documentation & Support

- **Enhanced Source Code:** https://github.com/Stinocon/ialarm-mqtt
- **Add-on Repository:** https://github.com/Stinocon/addons
- **Configuration Guide:** https://github.com/maxill1/ialarm-mqtt/wiki/Configuration
- **Troubleshooting:** https://github.com/maxill1/ialarm-mqtt/wiki/Troubleshooting

## Important Notes

- **TCP Implementation:** Since version 2.0, this addon uses TCP implementation. Ensure port is set to `18034` (not `80`)
- **Zone Limit:** Maximum 40 zones supported per alarm panel
- **Coexistence:** This version can run alongside the original maxill1 addon without conflicts
- **Version Alignment:** Addon versions are aligned with the underlying ialarm-mqtt library

## Migration from Original

If migrating from the original addon:

1. **No conflicts:** This version uses different MQTT topics and unique IDs
2. **Parallel installation:** You can install both versions simultaneously
3. **Gradual migration:** Test this version while keeping the original running
4. **Configuration compatibility:** Same configuration format with optional branding section

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and recent improvements.