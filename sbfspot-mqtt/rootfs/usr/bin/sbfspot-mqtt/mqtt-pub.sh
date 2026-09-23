#!/usr/bin/env bash
# Publishes one retained message to the broker, with the credentials written at startup.
#
# This exists so the MQTT password stays out of SBFspot's command line. SBFspot builds its
# publish command as a shell string and runs it with system(3), so a credential passed through
# its configuration would be readable in `ps`, quoted by rules of their own, and printed in its
# log. Here the password is read from a 600 file at the moment it is used.
#
# It still ends up as the `-P` argument of mosquitto_pub, which has no option to read it from a
# file: that argument is visible to processes in this container and on the host. The README
# states it rather than implying otherwise.
#
# Usage: mqtt-pub.sh <topic> <message>
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "mqtt-pub.sh: expected <topic> <message>, got $# argument(s)" >&2
    exit 2
fi

readonly topic="$1"
readonly message="$2"
readonly credentials=/data/mqtt.json

if [[ ! -r "${credentials}" ]]; then
    echo "mqtt-pub.sh: ${credentials} is missing or unreadable" >&2
    exit 1
fi

host="$(jq -r '.host' "${credentials}")"
port="$(jq -r '.port' "${credentials}")"
username="$(jq -r '.username // ""' "${credentials}")"
password="$(jq -r '.password // ""' "${credentials}")"

args=( -h "${host}" -p "${port}" -t "${topic}" -m "${message}" -r )
# Either, not both: a broker configured with a password and no user name is unusual but real, and
# requiring a user name before sending the password would drop the credential without saying so.
if [[ -n "${username}" || -n "${password}" ]]; then
    args+=( -u "${username}" -P "${password}" )
fi

# mosquitto_pub has no connect timeout. Against a broker that is unreachable rather than
# refusing, it waits for the kernel's TCP timeout -- about two minutes -- and that wait happens
# inside the poll, which would turn a mistyped remote host into a bridge that polls every three
# minutes instead of every one. Exit 124 is a failure everywhere this is called from.
exec timeout 15 mosquitto_pub "${args[@]}"
