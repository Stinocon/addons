# Home Assistant Add-ons: Stinocon custom repository (ialarm-mqtt fixed)

🚀 **Enhanced iAlarm MQTT integration with critical bug fixes and coexistence support.**

This repository provides fixed versions of the ialarm-mqtt add-on that can **coexist side-by-side** with the original addon using different MQTT prefixes and unique identifiers.

## 🔧 Key Improvements

- ✅ **Fixed bugs #45 and #51** - Entity name flip-flop and HA 2024.2+ compliance
- ✅ **Coexistence support** - Run alongside original addon without conflicts  
- ✅ **MQTT prefix `ialarm-v2`** (vs `ialarm` in original)
- ✅ **Unique device identifiers** - No Home Assistant entity conflicts
- ✅ **Enhanced logging** and discovery management

## 📦 Installation

Add this custom repository to Home Assistant:

```
https://github.com/Stinocon/addons
```

See [Home Assistant documentation](https://www.home-assistant.io/common-tasks/os#installing-third-party-add-ons) for detailed installation steps.

## Add-ons provided by this repository

- **[ialarm-mqtt](ialarm-mqtt/README.md)** `v0.12.3`

    iAlarm MQTT integration for Home Assistant (fixed version with coexistence support).
    
- **[ialarm-mqtt-dev](ialarm-mqtt-dev/README.md)**

    iAlarm MQTT integration for Home Assistant (development branch).

## 🤝 Coexistence with Original

This addon can run **simultaneously** with the original maxill1/ialarm-mqtt addon:

| Feature | Original | Stinocon Version |
|---------|----------|------------------|
| MQTT Topics | `ialarm/*` | `ialarm-v2/*` |
| Device Name | `iAlarm Security Panel` | `iAlarm Security Panel (Stinocon)` |
| Unique IDs | `alarm_mqtt_xxx` | `alarm_mqtt_xxx_stinocon` |
| Manufacturer | `Meian` | `Stinocon Mods` |

## 🔗 Source Code

- **Add-on Repository:** https://github.com/Stinocon/addons
- **iAlarm-MQTT Source:** https://github.com/Stinocon/ialarm-mqtt

## 📝 License

This project maintains the same license as the original work.