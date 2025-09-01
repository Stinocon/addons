# Home Assistant Add-ons: Stinocon custom repository (ialarm-mqtt fixed)

🚀 **Enhanced iAlarm MQTT integration with critical bug fixes and coexistence support.**

This repository provides an enhanced version of the ialarm-mqtt add-on with critical bug fixes and improved entity naming.

## 🔧 Key Improvements

- ✅ **Fixed bugs #45 and #51** - Entity name flip-flop and HA 2024.2+ compliance
- ✅ **Clean entity naming** - No more ugly _2, _3, _4 suffixes (e.g., "Cantina", "Cantina Stato", "Cantina Batteria")
- ✅ **MQTT prefix `ialarm-v2`** (vs `ialarm` in original)
- ✅ **Unique device identifiers** - No Home Assistant entity conflicts
- ✅ **Enhanced logging** and discovery management
- ✅ **Professional branding** - Antifurto365 manufacturer with customizable naming

## 📦 Installation

Add this custom repository to Home Assistant:

```
https://github.com/Stinocon/addons
```

See [Home Assistant documentation](https://www.home-assistant.io/common-tasks/os#installing-third-party-add-ons) for detailed installation steps.

## Add-ons provided by this repository

- **[ialarm-mqtt](ialarm-mqtt/README.md)** `v0.12.6`

    iAlarm MQTT integration for Home Assistant (enhanced version with clean entity naming).

## ⚠️ Important Connection Limitation

**IMPORTANT:** The iAlarm central unit allows only **one connection at a time**. You cannot run both the original and this enhanced version simultaneously.

**However,** this enhanced version provides better configuration options and can replace the original addon:

| Feature | Original | Stinocon Version |
|---------|----------|------------------|
| MQTT Topics | `ialarm/*` | `ialarm-v2/*` |
| Device Name | `iAlarm Security Panel` | `iAlarm Security Panel (ialarm)` |
| Unique IDs | `alarm_mqtt_xxx` | `alarm_mqtt_xxx_ialarmv2` |
| Manufacturer | `Meian` | `Antifurto365` |
| Entity Names | Ugly _2, _3, _4 suffixes | Clean descriptive names |

## 🔗 Source Code

- **Add-on Repository:** https://github.com/Stinocon/addons
- **iAlarm-MQTT Source:** https://github.com/Stinocon/ialarm-mqtt

## 📝 License

This project maintains the same license as the original work.