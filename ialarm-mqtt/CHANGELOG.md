# Changelog

## 1.5.1 - THE START-UP LOG IS FINALLY QUIET

- **THE BLOCK THAT SURVIVED**: 1.5.0 was meant to move the noisy discovery logging to debug,
  and moved everything except the part that prints on every start — the
  `=== DISCOVERY DEBUG ===` header with the full zone dump. The edit had been applied to the
  wrong file, where it matched nothing and failed without complaining. Spotted in a real
  add-on log after the release, not before it.
- **ALSO LOWERED**: `Discovery called`, `Starting discovery process`, `Creating
  reset/discovery messages`, `Created N messages`, `createMessages called` and `Starting zone
  iteration`. And `Publishing HA discovery reset for N topics` now appears only when there is
  something to clear, which on a normal start there no longer is.
- **WHAT A START STILL TELLS YOU**: whether discovery ran and with which settings, how many
  entities were published, and every topic sent. Set the add-on to `verbose` to get the rest
  back when troubleshooting.
- Logging only: no entity, option or behaviour changes. Requires ialarm-mqtt 0.15.21.

## 1.5.0 - NODE 18, AND A COMPARISON THAT MISSED NESTED CHANGES

- **NODE 16 IS GONE**: the image ran on Node 16.20, out of support since September 2023. The
  base image moves from `hassio-addons/base:12.2.6` (Alpine 3.16) to `14.1.3` (Alpine 3.18),
  which brings **Node 18.20**. That is as far as the Home Assistant ecosystem goes today: no
  community or official base ships Node 20 or later, so this is an improvement rather than a
  destination.
- **BUILD FIXES THAT CAME WITH IT**: npm 9 removed `unsafe-perm`, so `npm config set
  unsafe-perm true` failed the build outright instead of warning; `--only=production` and
  `--no-optional` became `--omit=dev` and `--omit=optional`.
- **TESTED IN A REAL CONTAINER, NOT JUST BUILT**: the s6 service scripts use the legacy
  format and the base skips two major versions, so the image was run locally before release.
  The service starts (`copying legacy longrun ialarm-mqtt`), the bridge comes up on Node
  18.20.1, and `docker stop` shuts everything down with exit code 0.
- **STALE COMMUNICATION STATUS FIXED** (bridge 0.15.20): the routine deciding whether a
  payload changed never compared anything below the top level. The visible effect was on the
  communication status sensor, whose values all live one level down: a connection error could
  take up to five minutes to reach Home Assistant. It is now reported immediately.
- **QUIETER LOG**: the discovery debug block, the per-zone placeholder identifiers, the
  disabled-zone filtering and the caching line duplicating every publish are now debug level.
- **THE BRIDGE NOW HAS TESTS**: 65 checks (`npm test` in the source repository) covering the
  discovery payloads, the identifiers your manual renames depend on, the reset staying
  opt-in, the reconnection backoff and the polling lifecycle. They run against a real MQTT
  broker without a panel.
- Requires ialarm-mqtt 0.15.20.

## 1.4.2 - COMMANDS NO LONGER FIGHT THE POLLING FOR THE CONNECTION

- **THE BUG**: arm, disarm and bypass are supposed to pause the status polling while their
  command travels to the panel, because the panel accepts a single TCP connection at a time.
  The pause never happened: the code cleared the *array* of timers instead of the timers
  inside it. Commands and polling talked over each other, which is where the "a request is in
  progress, we will wait" log lines came from.
- **NOW**: the pause works, and the polling resumes when the command is answered. A watchdog
  restarts it anyway after 30 seconds if an answer never arrives, so a lost command cannot
  leave the bridge running but silent.
- **TIMERS SEPARATED**: availability, diagnostics and the watchdog no longer share the list
  with the status polling, so a command does not restart their interval. Before, on a busy
  hour, the diagnostics timer could be reset often enough never to fire.
- **HONEST AVAILABILITY**: the 5-minute availability timer no longer republishes "online"
  while the panel link is down, undoing the "offline" published when it dropped.
- **DIAGNOSTICS WHEN THEY MATTER**: the service timers now start with the MQTT connection
  instead of the panel one, so the health payload is published exactly when the panel cannot
  be reached.
- Requires ialarm-mqtt 0.15.19.

## 1.4.1 - THE BRIDGE NO LONGER GIVES UP ON AN UNREACHABLE PANEL

- **THE BUG**: if the panel did not answer when the add-on started, the bridge stopped for
  good. Its retry was gated behind "more than 10 errors", but the first connection refusal
  was followed by a disconnect that reset the counter, and with no connection there was
  nothing left to produce further errors. Polling never started either, since it starts once
  connected. Only restarting the add-on brought it back.
- **NOW**: reconnection follows the connection state instead of an error count. One attempt
  is queued at a time with exponential backoff — 5s, 10s, 20s, 40s, up to 60s — and keeps
  going for as long as the panel is unreachable. When the panel answers, the backoff resets.
- **VISIBLE FROM HOME ASSISTANT**: `sensor.ialarm_diagnostics` gained the `reconnectAttempts`
  and `nextReconnectAt` attributes, so "it is retrying, next attempt in 40s" can be read
  without opening the log.
- Requires ialarm-mqtt 0.15.18.

## 1.4.0 - NO MORE HISTORY GAPS ON RESTART

- **WHY**: every start-up published an empty payload to all the discovery `/config` topics
  before republishing them. That deletes and recreates every entity, so Home Assistant showed
  them as `unavailable → unknown → <value>` on each restart. The history of every sensor was
  interrupted, and any automation triggering on an explicit `from:` silently missed the
  transition that happened across the restart — which is exactly how a low-battery flag can
  pass unnoticed.
- **NOW**: on start the entity configs are published directly and Home Assistant updates the
  existing entities in place. No deletion, no gap, and the 5-second wait that existed only to
  let HA process the cleanup is gone: entities appear immediately.
- **THE CLEANUP IS STILL THERE, ON DEMAND**: the **Discovery Reset** switch (and the
  `{prefix}/alarm/discovery` topic) still clears every config first, then republishes. Use it
  after disabling a feature, to remove the entities it left behind. With discovery disabled in
  the configuration the cleanup also still runs, since removing the entities is the point.
- **OLD BEHAVIOUR AVAILABLE**: set `hadiscovery.resetOnStart: true` to clean up at every start
  as before.
- **QUIETER START**: the cleanup addresses all 128 zones the panel can have — about a thousand
  MQTT messages that no longer go out at every restart.
- Manual renames were never at risk either way: Home Assistant keys them to `unique_id`, which
  this release does not touch.

## 1.3.0 - BRIDGE DIAGNOSTICS IN HOME ASSISTANT

- **WHY**: until now the only way to know whether the bridge was still talking to the panel
  was to open the add-on log. Four diagnostic sensors now carry that state into Home
  Assistant, where it can be seen on a dashboard and used in automations.
- **NEW `diagnostics` FEATURE**: adds, on the alarm device,
  - `sensor.ialarm_diagnostics` — `ok` / `degraded` / `starting` / `offline`, with the full
    payload as attributes: panel connection status, uptime, poll counters, last error and
    when it happened, zones loaded, last discovery;
  - `sensor.ialarm_last_poll` — timestamp of the last successful read from the panel, so an
    automation can fire on "no successful read for 5 minutes";
  - `sensor.ialarm_connection_errors` and `sensor.ialarm_panel_disconnections` — counters
    since the bridge started.
- **COST CONTROL**: the payload is published on its own timer (`server.polling_diagnostics`,
  default 60000 ms), not at the status-polling rate, plus immediately on connect, disconnect,
  error and discovery. It would otherwise write to the HA recorder every few seconds.
- **NO AVAILABILITY TOPIC** on these four entities, on purpose: availability goes offline
  exactly when the panel link drops, which is when these values are worth reading. The
  `lastUpdated` attribute says how fresh the payload is.
- **EXISTING INSTALLS**: saved add-on options are not migrated, so add `diagnostics` to your
  `server.features` list to enable it. Nothing else changes — no existing entity, unique ID
  or manual rename is touched.

## 1.2.3 - PROVENANCE AND SERVICE SCRIPTS

- **PROVENANCE**: the last two files still identical to upstream's — the s6 `run` and
  `finish` scripts — have been rewritten. `maxill1/addons` declares no licence, so those 51
  lines were the only ones this repository redistributed without an explicit permission.
  Nothing under `ialarm-mqtt/` is byte-identical to upstream any more, and the MIT grant in
  the repository `LICENSE` now covers this packaging without a caveat. The git history is
  untouched and stays the record of where the add-on came from.
- **VERSIONS IN THE LOG**: `run` now reads the versions with node instead of a
  `grep | head | awk | sed` chain. The old chain took the first line containing "version",
  which is not necessarily the package's own — a dependency's would do.
- **STRAY ARGUMENT REMOVED**: the bridge was started with its own entry point repeated as
  the first argument, a leftover from when the line read `node "${options[@]}"`. Its parser
  keeps only the flags it knows, so the stray path was read and discarded on every start.
  Verified against the parser in `bin/ialarm-mqtt.js`: both forms yield the same options.
- **HONEST SHUTDOWN LOG**: `finish` no longer logs "restarting" while it is halting the
  add-on, and says which exit code it saw. A log that contradicts what is happening sends
  whoever reads it looking in the wrong place.

No functional change to the bridge itself.

## 1.2.2 - 🐛 FIX STALE CODE IN BUILDS (CACHE-BUST)
- **🐛 BUILD FIX**: The Docker build cached the `git clone` of the source repo, so since the builder migration the add-on shipped **stale code** (e.g. 1.2.1 was missing `default_entity_id`). Added a cache-bust so every build pulls the current `master`.
- **ℹ️ IMPACT**: this is the version that actually ships the clean zone ID entity IDs from 1.2.1. Update to 1.2.2, restart, then recreate the zone ID entities (see README) to get `sensor.<zone>_ialarm_id_zona`.

## 1.2.1 - 🏷️ CLEAN ENTITY IDS FOR ZONE ID SENSORS
- **🏷️ CLEAN ENTITY IDS**: The zone ID sensors now publish a `default_entity_id` → `sensor.<zone>_ialarm_id_zona` and `sensor.ialarm_zone_directory` (no more long auto-generated IDs).
- **📚 DOCS**: Documented the full `features` list and what each feature does.
- **ℹ️ NOTE**: default entity IDs only apply on first creation — delete previously created zone ID entities once to have them recreated with the clean IDs.

## 1.2.0 - 🔢 ZONE ID INDICATORS
- **🔢 PER-ZONE ID SENSOR**: New diagnostic sensor on each zone device showing the panel zone id (e.g. `6`), so a number on the panel/app maps to a room in HA.
- **🗺️ ZONE DIRECTORY**: New diagnostic sensor on the alarm device with the full `id → name` map in its attributes — ideal for automations (e.g. "which zone is open and blocking arming?").
- **⚙️ FEATURE FLAG**: Both are gated by the new `zoneId` feature. Add `zoneId` to the addon `features` list to enable. Reuses existing MQTT data: no impact on existing entities or their manual renames.

## 1.1.0 - 🎛️ CONFIGURABLE ALARM MODES
- **🎛️ supported_features**: The `alarm_control_panel` discovery now publishes `supported_features`, so Home Assistant only shows the arm modes the addon actually supports.
- **✅ DEFAULT**: Defaults to `arm_home` + `arm_away` → only **Home / Away / Disarm** buttons (Disarm is always available).
- **🧹 NO MORE DEAD BUTTONS**: Removes the unused **Night / Vacation / Custom bypass** buttons that HA showed by default.
- **⚙️ CONFIGURABLE**: New `hadiscovery.supportedFeatures` option (allowed values: `arm_home`, `arm_away`, `arm_night`, `arm_vacation`, `arm_custom_bypass`, `trigger`).

## 0.15.5 - 🔍 DEBUG LOGGING FOR ZONE PREFIX ANALYSIS
- **🔍 DEBUG LOGGING**: Added comprehensive debug logging to cleanZoneName function
- **📊 INPUT LOGGING**: Log original zone name input
- **📊 PREFIX LOGGING**: Log extracted zone prefix
- **📊 NAME PART LOGGING**: Log name part after prefix removal
- **📊 RESULT LOGGING**: Log final result of cleaning function
- **🎯 TROUBLESHOOTING**: This version helps identify why zone prefix is not preserved

### Debug Log Examples:
- `cleanZoneName INPUT: "zona_15_pir_studio_pir_studio"`
- `cleanZoneName EXTRACTED PREFIX: "zona_15_"`
- `cleanZoneName NAME PART: "pir_studio_pir_studio"`
- `cleanZoneName RESULT (4-part dup): "zona_15_pir_studio"`

### Current Issue Being Debugged:
- **Expected**: `binary_sensor.zone_15_pir_studio_batteria`
- **Actual**: `binary_sensor.pir_studio_pir_studio_batteria`

## 0.15.4 - 🎯 INCREMENTAL NAMING FIX - KEEP ZONE PREFIX, REMOVE DUPLICATIONS
- **🎯 INCREMENTAL FIX**: Keep zone prefix but remove duplications
- **✅ ENHANCED CLEANZONENAME**: Now preserves zone_X_ prefix while removing duplications
- **✅ SMART PREFIX HANDLING**: Extracts and preserves zone prefix (zone_15_, zona_15_)
- **✅ DUPLICATION REMOVAL**: Removes duplications in the name part only
- **✅ UNIQUE_ID V6**: Updated to v6 for force refresh

### Naming Examples:
- **Input**: `"zona_15_pir_corridoio_pir_corridoio"`
- **Output**: `"zone_15_pir_corridoio"` (keeps prefix, removes duplication)

### Expected Entity Results:
- ✅ `binary_sensor.zone_15_pir_corridoio_connessione`
- ✅ `binary_sensor.zone_15_pir_corridoio_batteria`
- ✅ `binary_sensor.zone_15_pir_corridoio_stato`
- ✅ `switch.zone_15_pir_corridoio_bypass`

### Instead of:
- ❌ `binary_sensor.pir_corridoio_pir_corridoio_connessione`
- ❌ `binary_sensor.zone_15_pir_corridoio_pir_corridoio_connessione`

### Following Emergency Rules:
- ✅ **Minimal change**: Only enhanced cleanZoneName()
- ✅ **Functionality preserved**: All existing logic intact
- ✅ **Incremental approach**: One small change at a time

## 0.15.3 - 🚨 EMERGENCY ROLLBACK - RESTORE WORKING FUNCTIONALITY
- **🚨 EMERGENCY ROLLBACK**: Restore entity generation functionality
- **✅ RESTORED CLEANZONENAME**: Back to working version that generates entities
- **✅ RESTORED CONFIGBINARYSENSORS**: Back to original working version
- **✅ RESTORED SENSOR FUNCTIONS**: All sensor functions back to working versions
- **✅ RESTORED UNIQUE_ID V5**: Back to v5 (working version)
- **✅ ADDED DEBUG LOGGING**: Emergency debug logging for discovery process

### Priority: Functionality First!
- **PRIORITY**: Restore entity generation functionality first!
- **Naming improvements**: Can be done incrementally later
- **This should restore**: The working state where entities are generated

### What's Restored:
- ✅ Entity generation should work again
- ✅ All discovery messages should be published
- ✅ Home Assistant should receive entity configurations
- ✅ Debug logging added for troubleshooting

## 0.15.2 - 🎯 MINIMAL FIX - PERFECT NAMING WITHOUT BREAKING FUNCTIONALITY
- **🎯 MINIMAL FIX**: Perfect naming without breaking existing functionality
- **✅ ENHANCED CLEANZONENAME**: Better duplication handling for entity IDs
- **✅ CLEANZONAMEFORDISPLAY**: Readable device names with spaces and proper capitalization
- **✅ UPDATED GETZONEDEVICE**: Uses display names for beautiful device names
- **✅ UPDATED SENSOR CALLS**: All sensors use clean entity names
- **✅ UNIQUE_ID V8**: Updated to _v8 for force refresh of all entities

### Perfect Naming Examples:
- **Device Names**: "PIR Sala", "Finestra Studio", "Camera"
- **Entity IDs**: `pir_sala`, `pir_sala_stato`, `pir_sala_batteria`, `pir_sala_connessione`, `pir_sala_bypass`

### Test Cases:
- Input: `"zona_15_pir_corridoio_pir_corridoio"` → Display: "PIR Corridoio" 📱, Entity: `pir_corridoio` 🏷️
- Input: `"zona_8_porta_studio_porta_studio"` → Display: "Porta Studio" 📱, Entity: `porta_studio` 🏷️
- Input: `"bagno_bagno"` → Display: "Bagno" 📱, Entity: `bagno` 🏷️

### What's NOT Changed:
- ✅ Keeps all existing functionality intact
- ✅ configBinarySensors remains unchanged (except unique_id bump)
- ✅ All valueTemplate and core logic preserved
- ✅ Discovery system unchanged

## 0.15.1 - 🎯 PERFECT ENTITY NAMING
- **🎯 PERFECT ENTITY NAMING**: Two separate functions for device names vs entity IDs
- **✅ CLEANZONAMEFORDISPLAY**: Readable device names with spaces and proper capitalization
- **✅ CLEANZONAMEFORENTITY**: Clean entity IDs with underscores and lowercase
- **✅ UPDATED SENSOR FUNCTIONS**: All sensors now use clean entity names
- **✅ UNIQUE_ID V7**: Updated to _v7 for force refresh of all entities

### Perfect Naming Examples:
- **Device Names**: "PIR Sala", "Finestra Studio", "Camera"
- **Entity IDs**: `pir_sala`, `pir_sala_stato`, `pir_sala_batteria`, `pir_sala_connessione`, `pir_sala_bypass`

### Test Cases:
- Input: `"zona_15_pir_corridoio_pir_corridoio"` → Display: "PIR Corridoio" 📱, Entity: `pir_corridoio` 🏷️
- Input: `"zona_8_porta_studio_porta_studio"` → Display: "Porta Studio" 📱, Entity: `porta_studio` 🏷️

## 0.15.0 - 🎉 STABLE RELEASE
- **🎉 STABLE RELEASE**: Clean Entity Naming + Repository Cleanup
- **✅ ENTITY NAMING FIXES**: Entity IDs now clean (pir_sala vs zone_18_pir_sala_pir_sala)
- **✅ ENHANCED CLEANZONENAME**: Aggressive deduplication with comprehensive pattern matching
- **✅ UNIQUE_ID V6**: Updated to _v6 for force refresh of all entities
- **✅ IMPROVED GETZONEDEVICE**: Clean device names without redundant prefixes
- **✅ REPOSITORY CLEANUP**: Updated .gitignore, removed obsolete v0.12.x tags
- **✅ PRODUCTION READY**: Clean, stable, and maintainable codebase

### Entity Naming Examples:
- Before: `binary_sensor.zone_18_pir_sala_pir_sala` → After: `binary_sensor.pir_sala`
- Before: `binary_sensor.zone_14_camera_camera` → After: `binary_sensor.camera`
- Before: `binary_sensor.zone_9_finestra_studio_finestra_studio_batteria` → After: `binary_sensor.finestra_studio_batteria`

## 0.14.12
- **COMPREHENSIVE DISCOVERY ROBUSTNESS FIXES**: Make discovery system much more robust
- fix: make publishHomeAssistantMqttDiscovery more robust with better error handling
- fix: enhance cleanZoneName with comprehensive null/undefined handling
- fix: make createMessages zone loop more resilient to individual zone errors
- fix: add message validation to filter out invalid messages
- fix: improve error recovery and continue processing on individual failures

## 0.14.11
- **CLEANZONENAME NULL CHECK FIX**: Add null check in cleanZoneName to handle undefined zone names
- fix: add null check in cleanZoneName to handle undefined zone names
- fix: resolve TypeError: Cannot read properties of undefined (reading 'replace')
- fix: ensure cleanZoneName handles undefined/null zoneName gracefully

## 0.14.10
- **CRITICAL DISCOVERY FIX**: Fix zones variable not defined in createMessages
- fix: assign zonesToConfig to zones variable in createMessages
- fix: resolve ReferenceError: zones is not defined
- fix: ensure zones variable is available in createMessages scope

## 0.14.9
- **DISCOVERY ERROR CATCHING**: Add try-catch to catch createMessages() errors
- debug: add try-catch to catch createMessages() errors
- debug: catch and log errors in reset message creation
- debug: catch and log errors in discovery message creation
- debug: add error stack trace logging for debugging

## 0.14.8
- **IAlarmHaDiscovery INSTANTIATION DEBUGGING**: Add detailed logging for IAlarmHaDiscovery instantiation
- debug: add detailed logging for IAlarmHaDiscovery instantiation
- debug: log before and after IAlarmHaDiscovery instantiation
- debug: log before and after createMessages() calls
- debug: separate logging for reset and discovery message creation
- debug: track where the discovery process gets stuck

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