# Home Assistant Add-ons: iAlarm MQTT Bridge (Enhanced)

🚀 **Enhanced iAlarm MQTT integration with critical bug fixes and clean entity naming.**

This repository provides an enhanced version of the iAlarm MQTT bridge with critical bug fixes, improved entity naming, and professional branding.

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

- **[iAlarm MQTT bridge](ialarm-mqtt/README.md)** `v0.14.0`

    Enhanced iAlarm MQTT bridge with clean entity naming and bug fixes.

## ⚠️ Important Connection Limitation

**IMPORTANT:** The iAlarm central unit allows only **one connection at a time**. You cannot run both the original and this enhanced version simultaneously.

**However,** this enhanced version provides better configuration options and can replace the original addon:

| Feature | Original | Enhanced Version |
|---------|----------|------------------|
| MQTT Topics | `ialarm/*` | `ialarm/*` (same) |
| Device Name | `iAlarm Security Panel` | `iAlarm Security Panel` (same) |
| Unique IDs | `alarm_mqtt_xxx` | `alarm_mqtt_xxx` (same) |
| Manufacturer | `Meian` | `Meian` (same) |
| Entity Names | Ugly _2, _3, _4 suffixes | Clean descriptive names |

## 🔗 Source Code

- **Add-on Repository:** https://github.com/Stinocon/addons
- **iAlarm-MQTT Source:** https://github.com/Stinocon/ialarm-mqtt

## 📝 License

This project maintains the same license as the original work.