#!/usr/bin/env bash
# Tests for this add-on's own scripts, run by CI (.github/workflows/test-sbfspot-mqtt.yml).
#
# There is no application repository to hold them: SBFspot is compiled from upstream at image
# build time and never forked, so everything this add-on adds is packaging -- and packaging that
# nothing exercises is where a wrong regex lives for a year. shellcheck covers the two s6 scripts
# statically; what is tested here is behaviour, on a real broker.
#
# Usage: tests/glue.sh [add-on directory]
#
# Requires: jq, sed, mosquitto_pub/mosquitto_sub, a running MQTT broker on localhost:1883 with
# anonymous access, and permission to write /usr/bin/sbfspot-mqtt and /data (root, or sudo).
# The scripts address each other by absolute path because that is where the image puts them, so
# this test installs them there: it reproduces the image's layout (`COPY rootfs /`) instead of
# asking the scripts to learn a second one.
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly bin="${root}/rootfs/usr/bin/sbfspot-mqtt"
readonly installed=/usr/bin/sbfspot-mqtt
readonly data=/data
readonly credentials="${data}/mqtt.json"
readonly state_topic=sbfspot_mqtt/state
readonly availability_topic=sbfspot_mqtt/availability

failures=0

ok() { printf 'ok   - %s\n' "$1"; }
ko() { printf 'FAIL - %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"; failures=$((failures + 1)); }
check() {
    if [[ "$2" == "$3" ]]; then ok "$1"; else ko "$1" "$2" "$3"; fi
}

if ! command -v mosquitto_pub > /dev/null; then
    echo "mosquitto_pub is not installed: this test needs a broker and its clients" >&2
    exit 1
fi

# The layout the image has, with the working tree's scripts in it. Both directories are created
# here and not earlier: /data does not exist on a bare machine, and on CI it is created with
# sudo, so a plain `mkdir` before this point is a permission error -- which is how this test
# failed the first time it ran on a runner rather than in a container as root.
sudo=()
[[ "${EUID}" -eq 0 ]] || sudo=(sudo)
"${sudo[@]}" mkdir -p "${installed}" "${data}"
"${sudo[@]}" cp "${bin}"/*.sh "${installed}/"
"${sudo[@]}" chmod a+x "${installed}"/*.sh
[[ "${EUID}" -eq 0 ]] || sudo chown "$(id -u):$(id -g)" "${data}"
if [[ ! -w "${data}" ]]; then
    echo "cannot write ${data}" >&2
    exit 1
fi

# The same credentials file `run` writes before it polls anything.
printf '%s' '{"host":"localhost","port":1883,"username":"","password":"","topic":"sbfspot_mqtt/state","availability_topic":"sbfspot_mqtt/availability","discovery_prefix":"homeassistant"}' > "${credentials}"
chmod 600 "${credentials}"

if ! mosquitto_pub -h localhost -t smoke -m 1 2> /dev/null; then
    echo "no MQTT broker on localhost:1883" >&2
    exit 1
fi

# One reading, or "<missing>" if nothing was published at all -- so an assertion on an expected
# empty string cannot pass because the publish failed instead of because the value was empty.
key() {
    mosquitto_sub -h localhost -t "${state_topic}" -W 2 -C 1 2> /dev/null \
        | jq -r --arg k "$1" '.[$k] // "<missing>"'
}
config_of() {
    mosquitto_sub -h localhost -t "homeassistant/sensor/sbfspot_1234567890/$1/config" -W 2 -C 1 2> /dev/null || true
}
publish() { "${installed}/publish.sh" -m "$1" > /dev/null 2>&1 && echo 0 || echo $?; }

# ---------------------------------------------------------------------------------------------
# generate-config.sh: what the poller tells SBFspot, and the lines that are load-bearing.
# ---------------------------------------------------------------------------------------------
cfg="$(mktemp)"
BT_ADDRESS=00:11:22:33:44:55 INVERTER_PASSWORD=secret PLANT_NAME=TestPlant \
MQTT_TOPIC="${state_topic}" TIMEZONE=Europe/Rome "${bin}/generate-config.sh" "${cfg}"
check "generate-config writes the inverter address" "BTAddress=00:11:22:33:44:55" "$(grep '^BTAddress=' "${cfg}")"
# SynchTime=0 is what keeps the add-on read-only: upstream's default of 1 writes the plant clock
# over Bluetooth on every poll. A regression here silently starts writing to the inverter.
check "generate-config disables the clock write" "SynchTime=0" "$(grep '^SynchTime=' "${cfg}")"
check "generate-config writes no database" "CSV_Export=0" "$(grep '^CSV_Export=' "${cfg}")"
check "generate-config points MQTT at the publisher" "MQTT_Publisher=${installed}/publish.sh" "$(grep '^MQTT_Publisher=' "${cfg}")"
check "generate-config keeps the file private" "600" "$(stat -c %a "${cfg}")"
rm -f "${cfg}"

# ---------------------------------------------------------------------------------------------
# publish.sh: the payload SBFspot actually produces, including the two ways it is malformed.
# ---------------------------------------------------------------------------------------------
good='{"Timestamp": "2026-09-23T19:00:00","InvSerial": 1234567890,"InvName": "Test inverter","ETotal": 12345.67,"PACTot": 1234.5}'
check "a valid payload is accepted" "0" "$(publish "${good}")"
check "a valid payload is published as it arrived" "1234.5" "$(key PACTot)"
check "and the numbers are still numbers" "1234567890" "$(key InvSerial)"

# Upstream's to_keyvalue() collapses "" into ", so an empty value arrives unterminated:
# `"InvName": ""` becomes `"InvName": "`. This is what an inverter nobody named produces.
collapsed='{"Timestamp": "2026-09-23T19:00:00","InvSerial": 987654321,"InvName": ","InvStatus": "Ok"}'
check "the empty-value corruption is repaired, not refused" "0" "$(publish "${collapsed}")"
check "the empty value comes back as an empty string" "" "$(key InvName)"
check "the keys after the repaired one survive" "Ok" "$(key InvStatus)"

# The same corruption with a plant name that begins with a comma: a broader repair pattern would
# rewrite the plant name too and leave the payload refused for good.
awkward='{"Plantname": ",MyPlant","InvName": ","InvStatus": "Ok"}'
check "a comma-leading value is not mistaken for the corruption" "0" "$(publish "${awkward}")"
check "and the plant name survives intact" ",MyPlant" "$(key Plantname)"

# A message truncated by a single quote in a value cannot be repaired: the rest is gone.
before="$(key PACTot)"
check "a truncated payload is refused" "1" "$(publish '{"InvName": "O')"
check "and the previous reading is left standing" "${before}" "$(key PACTot)"
check "an empty message is refused before anything else" "2" "$(publish '')"

# ---------------------------------------------------------------------------------------------
# discovery.sh: the entities, from a payload shaped like the one a two-string inverter produces.
# ---------------------------------------------------------------------------------------------
payload='{"Timestamp":"2026-09-23T19:00:00","Plantname":"TestPlant","InvSerial":1234567890,"InvName":"Test inverter","InvTime":"2026-09-23T19:00:00","InvStatus":"Ok","InvTemperature":35.5,"InvGridRelay":"Closed","InvClass":"Solar Inverters","InvType":"SB 3000TL-20","InvSwVer":"03.30.06.R","EToday":12.34,"ETotal":12345.67,"PACTot":1234.5,"PDC1":1300.0,"PDC2":0.0,"IDC1":3.6,"IDC2":0.0,"UDC1":365.0,"UDC2":0.0,"GridFreq":50.01,"OperTm":34567.0,"FeedTm":33456.0}'
printf '%s' "${payload}" | "${installed}/discovery.sh" > /dev/null

# 11 fixed sensors plus six for the two strings upstream always reports -- see the README.
published="$(mosquitto_sub -h localhost -t 'homeassistant/#' -W 2 -v 2> /dev/null | grep -c 'homeassistant/sensor/sbfspot_' || true)"
check "discovery publishes 17 configurations" "17" "${published}"

power="$(config_of pactot)"
check "the power sensor carries its unit" "W" "$(printf '%s' "${power}" | jq -r '.unit_of_measurement')"
check "the power sensor carries its device class" "power" "$(printf '%s' "${power}" | jq -r '.device_class')"
check "the power sensor carries its state class" "measurement" "$(printf '%s' "${power}" | jq -r '.state_class')"
check "the power sensor reads the payload key" "{{ value_json.PACTot }}" "$(printf '%s' "${power}" | jq -r '.value_template')"
check "the device is registered once" "sbfspot_1234567890" "$(printf '%s' "${power}" | jq -r '.device.identifiers[0]')"
check "the device carries the model" "SB 3000TL-20" "$(printf '%s' "${power}" | jq -r '.device.model')"
check "the entities follow the availability topic" "${availability_topic}" "$(printf '%s' "${power}" | jq -r '.availability_topic')"

# The lifetime counter and the operating-time sensor are the two whose meaning a misconfiguration
# would quietly change, so they are asserted rather than assumed.
energy="$(config_of etotal)"
check "the lifetime energy is a total_increasing counter" "total_increasing" "$(printf '%s' "${energy}" | jq -r '.state_class')"
check "the lifetime energy is in kWh" "kWh" "$(printf '%s' "${energy}" | jq -r '.unit_of_measurement')"
operating="$(config_of opertm)"
check "operating time is a duration in hours" "duration/h" "$(printf '%s' "${operating}" | jq -r '.device_class')/$(printf '%s' "${operating}" | jq -r '.unit_of_measurement')"

# A key with no mapping must be reported and skipped, not published.
output="$(printf '%s' '{"InvSerial":1,"InvName":"X","SomethingNew":5}' | "${installed}/discovery.sh" 2>&1)"
if echo "${output}" | grep -q "no mapping for key 'SomethingNew'"; then
    ok "an unmapped key is reported, not published"
else
    ko "an unmapped key is reported, not published" "a warning naming the key" "${output}"
fi

echo
if (( failures > 0 )); then
    echo "${failures} test(s) failed"
    exit 1
fi
echo "all tests passed"
