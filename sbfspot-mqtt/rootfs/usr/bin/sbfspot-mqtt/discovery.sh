#!/usr/bin/env bash
# Publishes Home Assistant MQTT discovery for the keys SBFspot actually reported.
#
# The pool of possible keys is upstream's, and which of them carry a real value depends on the
# inverter model, its firmware and the strings it has. So the sensor set is not written down
# here as a wish list: this script reads the keys out of a real payload and publishes a sensor
# for each one it has a mapping for. A key with no mapping is logged and skipped, which is how
# a channel nobody has seen yet gets noticed instead of being invented.
#
# Idempotent and retained: running it again republishes the same configurations, which is what
# makes a changed sensor definition take effect on the next restart.
#
# Usage: discovery.sh < payload.json
set -euo pipefail

payload="$(cat)"
readonly payload

if ! jq -e 'type == "object" and (length > 0)' <<<"${payload}" > /dev/null; then
    echo "discovery.sh: the payload is not a non-empty JSON object; no discovery published" >&2
    exit 1
fi

credentials=/data/mqtt.json
readonly credentials
prefix="$(jq -r '.discovery_prefix // "homeassistant"' "${credentials}")"
readonly prefix
state_topic="$(jq -r '.topic' "${credentials}")"
readonly state_topic
availability_topic="$(jq -r '.availability_topic' "${credentials}")"
readonly availability_topic

serial="$(jq -r '.InvSerial // ""' <<<"${payload}")"
readonly serial
if [[ -z "${serial}" ]]; then
    echo "discovery.sh: the payload has no InvSerial, so there is no stable identifier to publish under" >&2
    exit 1
fi

# The device block. `InvName` is what the inverter was named in Sunny Explorer and is empty
# when nobody named it; the fallback names the model instead of inventing a name.
inverter_name="$(jq -r '.InvName // ""' <<<"${payload}")"
readonly inverter_name
model="$(jq -r '.InvType // ""' <<<"${payload}")"
readonly model
sw_version="$(jq -r '.InvSwVer // ""' <<<"${payload}")"
readonly sw_version
node_id="sbfspot_${serial}"
readonly node_id

if [[ -n "${inverter_name}" ]]; then
    device_name="${inverter_name}"
elif [[ -n "${model}" ]]; then
    device_name="SMA ${model}"
else
    device_name="SMA inverter ${serial}"
fi

publish() {
    # publish <key> <name> <unit> <device_class> <state_class> <icon> <entity_category>
    local key="$1" name="$2" unit="${3:-}" device_class="${4:-}" state_class="${5:-}"
    local icon="${6:-}" category="${7:-}"

    local config
    config="$(jq -n \
        --arg name "${name}" \
        --arg unique_id "${node_id}_$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')" \
        --arg state_topic "${state_topic}" \
        --arg value_template "{{ value_json.${key} }}" \
        --arg availability_topic "${availability_topic}" \
        --arg device_name "${device_name}" \
        --arg device_id "${node_id}" \
        --arg model "${model}" \
        --arg sw_version "${sw_version}" \
        --arg serial "${serial}" \
        --arg unit "${unit}" \
        --arg device_class "${device_class}" \
        --arg state_class "${state_class}" \
        --arg icon "${icon}" \
        --arg category "${category}" \
        '{
            name: $name,
            unique_id: $unique_id,
            state_topic: $state_topic,
            value_template: $value_template,
            availability_topic: $availability_topic,
            payload_available: "online",
            payload_not_available: "offline",
            device: {
                identifiers: [$device_id],
                name: $device_name,
                manufacturer: "SMA Solar Technology AG",
                model: $model,
                sw_version: $sw_version,
                serial_number: $serial
            },
            unit_of_measurement: $unit,
            device_class: $device_class,
            state_class: $state_class,
            icon: $icon,
            entity_category: $category
        }
        | walk(if type == "object" then with_entries(select(.value != null and .value != "")) else . end)'
    )"

    /usr/bin/sbfspot-mqtt/mqtt-pub.sh \
        "${prefix}/sensor/${node_id}/$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')/config" \
        "${config}"
}

while read -r key; do
    case "${key}" in
        InvSerial|InvName|InvClass|InvType|InvSwVer|Plantname)
            # Device identity: it belongs in the device block above, not in a sensor.
            ;;
        PACTot)
            publish "${key}" "Power" "W" "power" "measurement" "mdi:flash" ;;
        EToday)
            publish "${key}" "Energy today" "kWh" "energy" "total_increasing" "mdi:solar-power" ;;
        ETotal)
            publish "${key}" "Energy total" "kWh" "energy" "total_increasing" "mdi:solar-power" ;;
        InvStatus)
            publish "${key}" "Status" "" "" "" "mdi:information-outline" ;;
        InvTemperature)
            publish "${key}" "Temperature" "°C" "temperature" "measurement" "mdi:thermometer" ;;
        InvGridRelay)
            publish "${key}" "Grid relay" "" "" "" "mdi:electric-switch" "diagnostic" ;;
        InvTime)
            publish "${key}" "Inverter time" "" "" "" "mdi:clock-outline" "diagnostic" ;;
        GridFreq)
            publish "${key}" "Grid frequency" "Hz" "frequency" "measurement" "mdi:sine-wave" ;;
        OperTm)
            publish "${key}" "Operating time" "h" "duration" "total_increasing" "mdi:timer-outline" ;;
        FeedTm)
            publish "${key}" "Feed-in time" "h" "duration" "total_increasing" "mdi:timer-outline" ;;
        Timestamp)
            publish "${key}" "Data timestamp" "" "" "" "mdi:clock-check-outline" "diagnostic" ;;
        UDC[0-9]*)
            publish "${key}" "DC voltage string ${key#UDC}" "V" "voltage" "measurement" "mdi:solar-panel" ;;
        IDC[0-9]*)
            publish "${key}" "DC current string ${key#IDC}" "A" "current" "measurement" "mdi:solar-panel" ;;
        PDC[0-9]*)
            publish "${key}" "DC power string ${key#PDC}" "W" "power" "measurement" "mdi:solar-panel" ;;
        *)
            echo "discovery.sh: no mapping for key '${key}' — extending the map in discovery.sh is what publishes it" >&2 ;;
    esac
done < <(jq -r 'keys[]' <<<"${payload}")

echo "discovery.sh: published discovery under ${prefix}/sensor/${node_id}/ for device ${device_name}"
