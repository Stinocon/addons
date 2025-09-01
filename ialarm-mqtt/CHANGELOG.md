# Changelog

## 0.14.7
- **IAlarmHaDiscovery DEBUGGING**: Add detailed logging to IAlarmHaDiscovery.createMessages
- debug: add detailed logging to IAlarmHaDiscovery.createMessages function
- debug: log function entry with reset and zones parameters
- debug: log reset cleanup message creation
- debug: log zone iteration start and progress
- debug: log function completion with message count
- debug: add progress logging every 10 zones

## 0.14.6
- **DISCOVERY DEBUGGING**: Add detailed logging for discovery process
- debug: add detailed logging for discovery process
- debug: log discovery process start and reset message creation
- debug: log discovery message creation with config details
- debug: log branding prefix and zones count
- debug: add logging to identify where discovery gets stuck

## 0.14.5
- **MQTT TOPIC PREFIX FIX**: Correct MQTT topic prefix and add discovery debugging
- fix: correct topicPrefix fallback from 'ialarm' to 'ialarm-v2'
- fix: ensure MQTT topics use correct prefix for coexistence
- debug: add detailed logging for discovery process
- debug: log discovery calls and parameters
- debug: log discovery blocking status and timing

## 0.14.4
- **ENHANCED DISCOVERY FIX**: Implement enhanced discovery blocking resolution
- fix: add aggressive discovery reset if stuck for more than 60 seconds
- fix: track discovery start time for better debugging
- fix: force reset discovery flag if it has been stuck too long
- improve: better logging with timestamps for discovery process
- improve: more robust discovery state management
- feat: add manual reset function for debugging discovery issues

## 0.14.3
- **DOCUMENTATION FIXES**: Fix addon documentation inconsistencies
- fix: correct branding defaults in README examples
- fix: remove contradictory coexistence information
- fix: clarify single connection limitation
- fix: update migration instructions
- docs: consistent branding defaults across all documentation
- improve: clear and accurate documentation

## 0.14.2
- **FIX BRANDING DEFAULTS**: Correct addon configuration defaults for proper coexistence
- fix: update branding defaults in config.yaml to enable coexistence with original addon
- fix: prefix: "ialarm-v2" (vs "ialarm" in original)
- fix: uniqueIdSuffix: "_ialarmv2" (vs "" in original)
- fix: deviceNameSuffix: " (Enhanced)" (vs "" in original)
- fix: manufacturer: "Antifurto365" (vs "Meian" in original)
- improve: now properly distinguishes from original addon by default

## 0.14.1
- **DEFINITIVE ENTITY NAMING FIX**: Implement robust cleanZoneName() function to eliminate all duplication patterns
- fix: handle patterns like 'pir_corridoio_pir_corridoio' -> 'pir_corridoio'
- fix: handle patterns like 'word1_word2_word1_word2' -> 'word1_word2'
- fix: handle complex duplication patterns with dynamic detection
- fix: force entity regeneration with unique_id version bump to v5
- feat: clean, professional entity names without redundancy
- feat: consistent entity suffixes: 'Stato', 'Batteria', 'Connessione', 'Bypass'
- feat: enhanced logging for debugging entity name generation
- improve: all entity names now use cleanZoneName() for consistent naming

## 0.14.0
- **RESET TO WORKING VERSION**: Reset to commit 2999761 which was working correctly
- Update version to 0.14.0 to avoid conflicts with existing builds
- This version has the correct entity naming and unique_id generation
- Clean slate to avoid version conflicts in Docker builds
- Should resolve all discovery and entity generation issues

## 0.12.12
- **ENHANCED FIX**: Enhanced discovery blocking resolution with aggressive reset
- fix: add aggressive discovery reset if stuck for more than 60 seconds
- fix: track discovery start time for better debugging
- fix: force reset discovery flag if it has been stuck too long
- improve: better logging with timestamps for discovery process
- improve: more robust discovery state management

## 0.12.11
- **CRITICAL FIX**: Resolve discovery blocking issue preventing entity generation
- fix: add safety timeout to reset discovery flag if it gets stuck
- fix: prevent 'Discovery already in progress, skipping...' from blocking entity generation
- fix: add proper cleanup of safety timeout when discovery completes normally
- feat: add manual reset function for debugging discovery issues
- improve: discovery flag now automatically resets after 30 seconds if stuck

## 0.12.10
- feat: revert to original branding defaults for cleaner configuration
- feat: use original "ialarm" prefix instead of "ialarm-v2"
- feat: remove uniqueIdSuffix and deviceNameSuffix by default
- feat: use original "Meian" manufacturer by default
- feat: maintain same MQTT topics and device names as original
- fix: cleaner configuration with original branding while keeping enhanced features

## 0.12.10
- fix: improve cleanZoneName function to handle duplicate patterns
- feat: add logic to detect and remove duplicate parts in zone names
- feat: handle cases like 'zona_8_porta_studio_porta_studio' -> 'porta_studio'
- feat: increment unique_id version to _v4 to force entity regeneration
- fix: properly clean zone names that contain duplicate patterns

## 0.12.9
- fix: clean zone names by removing zona_X_ prefix duplication
- feat: add cleanZoneName() function to remove 'zona_X_' prefix from zone names
- feat: update all entity naming to use cleaned zone names:
  - Fault sensor: "PIR Corridoio Stato" (instead of "zona_15_pir_corridoio_pir_corridoio_stato")
  - Battery sensor: "Porta Ingresso Batteria" (instead of "zona_20_porta_ingresso_porta_ingresso_batteria")
  - Connectivity sensor: "PIR Corridoio Connessione" (instead of "zona_15_pir_corridoio_pir_corridoio_connessione")
  - Alarm sensor: "PIR Corridoio" (instead of "zona_15_pir_corridoio_pir_corridoio")
  - Bypass switch: "PIR Corridoio Bypass" (instead of "zona_15_pir_corridoio_pir_corridoio_bypass")
- feat: update device names to use cleaned zone names
- feat: increment unique_id version to _v3 to force entity regeneration

## 0.12.8
- fix: correct entity naming and unique_id generation to eliminate _2, _3, _4 suffixes
- fix: configSensorFault unique_id now includes '_fault' suffix (was missing)
- feat: add '_v2' suffix to all unique_ids to force Home Assistant entity regeneration
- feat: ensure all sensor types have unique, descriptive names:
  - Fault sensor: "ZoneName Stato" with unique_id ending in "_fault_v2"
  - Battery sensor: "ZoneName Batteria" with unique_id ending in "_lowbat_v2"
  - Connectivity sensor: "ZoneName Connessione" with unique_id ending in "_wirelessloss_v2"
  - Alarm sensor: "ZoneName" with unique_id ending in "_alarm_v2"
  - Bypass switch: "ZoneName Bypass" with unique_id ending in "_bypass_v2"

## 0.12.7
- feat: rename addon from "ialarm-mqtt" to "iAlarm MQTT bridge" for better clarity
- feat: update repository title to "iAlarm MQTT Bridge (Enhanced)"
- feat: replace "Stinocon vs Original" with "Enhanced vs Original" for professional presentation
- feat: remove "Stinocon Enhanced" references throughout documentation
- feat: improve addon description and branding consistency
- feat: update repository.json with new professional naming

## 0.12.6
- fix: eliminate automatic _2, _3, _4 suffixes from Home Assistant entity names
- feat: specific entity names for each zone sensor type:
  - Fault sensor: "ZoneName Stato" (instead of generic name causing _2 suffix)
  - Battery sensor: "ZoneName Batteria" (instead of generic name causing _3 suffix)
  - Connectivity sensor: "ZoneName Connessione" (instead of generic name causing _4 suffix)
  - Alarm sensor: "ZoneName" (main sensor, no suffix needed)
  - Bypass switch: "ZoneName Bypass" (already clean)
- fix: professional entity naming without ugly automatic suffixes
- example: "Zona 33 Cantina" now generates clean names like "Cantina", "Cantina Stato", "Cantina Batteria"

## 0.12.5
- feat: cleaner entity naming without redundancy (e.g., "PIR Studio" instead of "zona_17_pir_studio_zona_17_pir_studio")
- feat: improved bypass entity naming (e.g., "PIR Studio Bypass" instead of "Bypass Zone 17 PIR Studio")
- feat: updated branding defaults for better coexistence:
  - prefix: "ialarm-v2" 
  - uniqueIdSuffix: "_ialarmv2"
  - deviceNameSuffix: " (ialarm)"
  - manufacturer: "Antifurto365"
- fix: ensure all entity names are clean and user-friendly

## 0.12.4
- docs: comprehensive Home Assistant add-on README with configuration examples
- docs: enhanced repository documentation with coexistence features
- docs: migration guide for users switching from original addon
- fix: remove inappropriate donation links from enhanced fork
- chore: improved branding prefix from ialarm-fixed to ialarm-v2

## 0.12.3
- **BREAKING: Enable coexistence with original ialarm-mqtt addon**
- feat: configurable MQTT prefix via `branding.prefix` (default: "ialarm-v2")
- feat: configurable unique_id suffix via `branding.uniqueIdSuffix` 
- feat: configurable device name suffix via `branding.deviceNameSuffix`
- feat: configurable manufacturer via `branding.manufacturer` (default: "Meian")
- fix: allow side-by-side deployment with upstream addon using different prefixes

## 0.12.2
- Fix: prevent duplicate HA discovery publishes (eliminates entity name flip-flop) - Issue #45
- Fix: comply with HA 2024.2+ entity naming rules - Issue #51  
- Add: structured logs for discovery topics and unique_id
- Add: discovery cooldown to prevent rapid re-triggers

## 0.12.0
- fixed stability issues https://github.com/maxill1/ialarm-mqtt/issues/23
- fixed max zones https://github.com/maxill1/ialarm-mqtt/issues/24
- fixed cache problems https://github.com/maxill1/ialarm-mqtt/issues/41
- fixed area arm/disarm https://github.com/maxill1/ialarm-mqtt/issues/20
- fixed hass.io addon missing alarm code https://github.com/maxill1/ialarm-mqtt/issues/40

## 0.10.1
- reverted back to ialarm-mqtt 0.10.1
- following versioning of ialarm-mqtt npm package 

## 2.0.8
- updated to node-ialarm and reworked code to handle all responses as events (no more promises, only event-emitters) - see [issue 23](https://github.com/maxill1/ialarm-mqtt/issues/23)
- handle of "response" events and "push" events
- "error" sensor removed and created a "status" sensor with attributes

## 2.0.7
- updated ialarm-mqtt@0.10.1
- Fixed publishing of zone with empty names (fix https://github.com/maxill1/ialarm-mqtt/issues/24)
- added server.zones in schema

## 2.0.6
- updated node-ialarm@0.5.1 and ialarm-mqtt@0.10.0
- messages queue with small delay (configurable) (attempt to fix https://github.com/maxill1/ialarm-mqtt/issues/23)
- features enabled/disabled via config: (useful to debug https://github.com/maxill1/ialarm-mqtt/issues/23)
  - armDisarm = alarm.armDisarm, alarm.getStatusArea/alarm.getStatusAlarm
  - sensors = alarm.getZoneStatus
  - events = alarm.getLastEvents
  - bypass = alarm.bypassZone
  - zoneNames = alarm.getZoneInfo
- logging refactoring  (useful to debug https://github.com/maxill1/ialarm-mqtt/issues/23)
- ha discovery availability refactoring
- multiple area support with different alarm_control_panel (fix https://github.com/maxill1/ialarm-mqtt/issues/20)
- 128 zone support (fix https://github.com/maxill1/ialarm-mqtt/issues/24)

## 2.0.5
- fixed triggered status
- improved logging
- disconnect on every tcp message received in attempt to fix [issue 23](https://github.com/maxill1/ialarm-mqtt/issues/23)
- zone config optional properties

## 2.0.4
- updated node-ialarm@0.4.4 and ialarm-mqtt@0.9.0
- name is now configurable in yaml
- QoS configurable in yaml
- polling_status reduced to 5 seconds
- devices are now splitted (alarm and zones)
- every zone has now 4 sensors: alarm, fault, lowbat and wirelessLoss and 1 bypass switch
- 3 new switches: 
    - clear cache
    - clear discovery
    - alarm triggered cancel (resets sensors "alarm" property on alarm panel)

## 2.0.3
- fixed zone message with node-ialarm@0.4.2
- logging node-ialarm version on init

## 2.0.2
changed dockerfile ensure we are using latest verion of ialarm-mqtt

## 2.0
switched to tcp implementation. Please update port from 80 to 18034

```yaml
server:
  port: 18034 
```
also remove deprecated 'pages':

```yaml
  pages:
    - /RemoteCtr.htm 
    - /Zone.htm
    - /SystemLog.htm 
```

## 1.2
custom pages support for web scraper. 
Example:

```yaml
server:
  pages:
    - /status.html
    - /Zone.html
    - /SystemLog.html
```

## 1.1

- Zones handled as an array of int (was a single int before with max zone value). 

example: if you have 17 zones, change 1.0 config from:

```yaml
server:
  zones: 17
```

to 1.1 version:

```yaml
server:
  zones: 
   - 1
   - 2
   - 3
   - 4
   - 5
   - 6
   - 7
   - 8
   - 9
   - 10
   - 11
   - 12
   - 13
   - 14
   - 15
   - 16
   - 17
```

you can exclude zones by removing it from the array:

```yaml
server:
  zones: 
   - 1
   - 2
   - 3
   - 4
   - 5
   #- 6
   #- 7
   #- 8
   - 9
   - 10
   #- 11
   - 12
   #- 13
   - 14
   #- 15
   - 16
   - 17
```

## 1.0

- First release