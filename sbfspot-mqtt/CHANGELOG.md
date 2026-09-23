# Changelog

## 0.1.0 - FIRST RELEASE

- **WHAT IT DOES**: polls an SMA Sunny Boy over Bluetooth with SBFspot and publishes the reading
  to Home Assistant over MQTT discovery — power, energy today and total, status, temperature, DC
  voltage/current/power per string, grid frequency, operating hours and the inverter's clock.
- **READ-ONLY, WHICH TOOK TWO LINES**: `-settime` is never passed, and the generated configuration
  sets `SynchTime=0`. Upstream's default for it is 1, and on a Bluetooth connection that writes the
  plant clock to the inverter on **every** poll — so the add-on would have written to the inverter
  once a minute while claiming not to. Nothing here writes to the inverter.
- **BUILT FROM SOURCE, PINNED**: SBFspot `V3.9.12`, `make nosql`, fetched at image build time and
  never vendored. The tag is the only place the build refers to it; the README and this file name
  the version too, and nothing keeps prose in sync — the Dockerfile is the one that decides what
  gets compiled.
- **AN EMPTY VALUE NO LONGER COSTS EVERY SENSOR**: upstream's `to_keyvalue()` ends with
  `boost::replace_all(key_value, "\"\"", "\"")`, which turns an empty string value into an
  unterminated string: `"InvName": ""` arrives as `"InvName": "` and the whole payload fails to
  parse. `InvName` is empty on an inverter nobody named. The publisher repairs exactly that case
  and republishes it, rather than turning one missing name into an add-on that looks like it cannot
  reach the inverter. A payload truncated by a `'` in a name is still refused, with the raw text in
  the log: that one cannot be repaired, and a half-payload is worse than a failed poll.
- **A BROKER RESTART NO LONGER STOPS THE ADD-ON**: publishing the availability topic is guarded, so
  a Mosquitto (or Home Assistant) restart mid-poll does not end the poll loop and halt the add-on
  through the `set -e` that was supposed to protect it.
- **THE MQTT PASSWORD IS NOT IN SBFSPOT'S COMMAND LINE**: it comes from the Supervisor's MQTT
  service when the options leave the broker empty, and reaches `mosquitto_pub` from a mode-600 file
  rather than through the shell string upstream builds, prints in its log and hands to `system(3)`.
  It does still appear as `-P` on `mosquitto_pub`'s own argument list, which the README states
  rather than pretends away.
- **UNAVAILABLE, NOT STALE**: three failed polls in a row publish `offline`, the entities go
  unavailable, and the next successful poll brings them back; stopping the add-on publishes
  `offline` too, so a stopped bridge does not leave hour-old values looking current. A failed poll
  is routine — the inverter sleeps, or another Bluetooth master took the connection — so it does
  not halt the add-on, while a start that cannot succeed does.
- **THE DC STRINGS ARE ALWAYS TWO**: the discovery is published from the first real reading, so
  the sensors describe the inverter that answered. One caveat is worth knowing in advance: upstream
  seeds both MPPT slots before every reading, so `PDC`/`IDC`/`UDC` always expand to string 1 *and*
  string 2, and a single-string inverter reports the second as 0. The other channels behave the
  same way — the list requested is fixed, and a model without a channel answers `0` or `?` — so a
  constant zero on the device page is the inverter not having that channel, not a fault. The
  add-on logs a key it has no mapping for rather than inventing one.
- **BUILD-TIME GATES**: the image fails to build if the compiled SBFspot cannot run, or if `ldd`
  finds a library it does not have. Debian's boost runtime packages are versioned, and a missing
  one would otherwise surface as a container that starts and dies at the first poll.
- **CHECKED BEFORE RELEASING**: against a disposable Home Assistant in a container, the discovery
  payloads create 17 entities under one device — 11 fixed sensors plus six for the two DC strings —
  with the expected units, device classes and state classes, and they follow the availability topic
  in both directions.
