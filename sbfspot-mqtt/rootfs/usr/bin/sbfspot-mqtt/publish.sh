#!/usr/bin/env bash
# SBFspot's MQTT publisher. SBFspot runs
#
#     <MQTT_Publisher> <MQTT_PublisherArgs>
#
# as a shell command line, and this script is what MQTT_Publisher points at, with
# MQTT_PublisherArgs set to `-m "{{message}}"`: SBFspot substitutes the message into it and, on
# Linux, turns the double quotes into single ones. So the command line that arrives here is
# `-m '{ "PACTot": 1234, ... }'`.
#
# The broker's credentials are not passed through that command line -- SBFspot's own line is a
# shell string, and a password in it would need quoting rules of its own, appear in SBFspot's
# log, and be readable in `ps`. They are read from /data/mqtt.json (mode 600) further down,
# which keeps them out of *that* line; see the README for the exposure that remains.
#
# What is checked here is the payload, because both failure modes are otherwise silent:
#
#   * Empty string values. Upstream's `to_keyvalue()` ends with
#     `boost::replace_all(key_value, "\"\"", "\"")`, so an empty value arrives as an
#     unterminated string: `,"InvName": ""` becomes `,"InvName": "` and the object no longer
#     parses. `InvName` is empty on an inverter nobody named in Sunny Explorer, which is a
#     normal inverter. It is repaired below rather than refused, because the intent is
#     unambiguous -- an empty value.
#   * Truncation. SBFspot's own end quoting is a single quote, so a `'` inside a value ends the
#     message early and takes everything after it with it. That one cannot be repaired, and a
#     half-payload published as a sensor that never updates again is worse than a refused poll.
set -euo pipefail

if [[ "${1:-}" != "-m" ]]; then
    echo "publish.sh: expected '-m <message>' from SBFspot, got '${1:-<nothing>}'" >&2
    exit 2
fi

# Not readonly: the empty-value repair below reassigns it. jq's parse errors go to stderr on their
# own, and the repair line explains itself.
message="${2:-}"

if [[ -z "${message}" ]]; then
    echo "publish.sh: SBFspot asked for a publish with an empty message" >&2
    exit 2
fi

valid_json_object() {
    printf '%s' "$1" | jq -e 'type == "object" and (length > 0)' > /dev/null
}

if ! valid_json_object "${message}"; then
    # The repair of the empty-value case, and only it: it is a rewrite of `: "` into `: ""`
    # where the *next thing* is the start of another key, which is what the collapse leaves
    # behind. The pattern is deliberately narrow -- requiring the quote that opens the next key
    # -- because a value that merely begins with a comma or a brace is legal, and a broader
    # pattern would rewrite those too, turning a repairable payload into a refused one. The
    # second expression covers the same corruption in the last position.
    repaired="$(printf '%s' "${message}" | sed -E 's/: ",(")/: "",\1/g; s/: "}$/: ""}/g')"
    if valid_json_object "${repaired}"; then
        echo "publish.sh: repaired an empty string value in SBFspot's payload (upstream collapses \"\" into \")." >&2
        message="${repaired}"
    else
        echo "publish.sh: refusing to publish a payload that is not a non-empty JSON object." >&2
        echo "publish.sh: if the payload is cut off mid-value, the cause is usually a single quote" >&2
        echo "publish.sh: in a name -- the inverter's name as set in Sunny Explorer, or plantname --" >&2
        echo "publish.sh: because SBFspot quotes its MQTT message with one. Raw payload follows:" >&2
        printf '%s\n' "${message}" >&2
        exit 1
    fi
fi

topic="$(jq -r '.topic' /data/mqtt.json)"
readonly topic
exec /usr/bin/sbfspot-mqtt/mqtt-pub.sh "${topic}" "${message}"
