# Deliberately without a default, for the same reason as ezviz-stream-bridge: this add-on's bases
# are architecture-specific (`{arch}-base-debian`), and the builder action does not pass BUILD_FROM
# by itself. A default here would quietly give one architecture the other one's base image. The
# value comes from build.yaml, per architecture, passed by the workflows.
ARG BUILD_FROM

# The two versions this image is made of, pinned to tags. Declared before the first FROM because
# that is what makes them visible to both stages: an ARG declared inside a stage exists only there,
# and a stage that redeclares it without a default inherits the global one -- which is how the check
# at the bottom of this file knows what was pinned.
ARG SBFSPOT_REF="V3.9.12"
ARG SBFSPOT_MQTT_REF="v0.1.1"

FROM ${BUILD_FROM} AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG SBFSPOT_REF
ARG SBFSPOT_MQTT_REF

# SBFspot is upstream and is compiled as released; sbfspot-mqtt is the program that drives it, and
# lives in its own repository.

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        g++ \
        make \
        libbluetooth-dev \
        libboost-date-time-dev \
        libboost-system-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${SBFSPOT_REF}" https://github.com/SBFspot/SBFspot.git .

# `nosql` and not `sqlite`/`mariadb`: this add-on publishes to MQTT and keeps no history of its own.
# Home Assistant already records the states it cares about, and a second database inside the
# container would be a second thing to back up, migrate and explain. Upstream's makefile documents
# the four flavours; the binary lands in nosql/bin/.
RUN make -C ./SBFspot nosql

# The program, from its own repository and never vendored. The cache-busting ADD is what makes a
# moved tag invalidate the clone below: without it BuildKit would serve the cached clone and the
# image would carry the older commit under the newer version.
ADD https://api.github.com/repos/Stinocon/sbfspot-mqtt/commits/${SBFSPOT_MQTT_REF} /tmp/sbfspot-mqtt-source.json
RUN git clone --depth 1 --branch "${SBFSPOT_MQTT_REF}" https://github.com/Stinocon/sbfspot-mqtt.git /src/sbfspot-mqtt


FROM ${BUILD_FROM} AS runtime

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Re-declared because an ARG before the first FROM is available in the FROM lines and not inside
# the stages; without this line the version check at the bottom compares against an empty string.
ARG SBFSPOT_MQTT_REF

# The runtime libraries are named here, version and all, because Debian's boost runtime packages
# are versioned and there is no unversioned metapackage to depend on. The `ldd` guard below turns a
# wrong guess into a failed build instead of a container that starts and dies at the first poll with
# "error while loading shared libraries" -- and the author of that message is nobody's friend.
#
# mosquitto-clients is not optional: SBFspot publishes through the program, which publishes through
# a mosquitto client, and without one it reports the failure and drops the reading.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libbluetooth3 \
        libboost-date-time1.83.0 \
        libboost-system1.83.0 \
        libstdc++6 \
        mosquitto-clients \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# SBFspot, with the data files it looks for next to itself: TagDefs reads TagList<LOCALE>.txt from
# there and falls back to en-US, which is the locale the generated configuration pins, so only that
# one is shipped -- the other five are ~450 KB each for a fallback that cannot trigger.
COPY --from=build /src/SBFspot/nosql/bin/SBFspot /usr/bin/sbfspot/SBFspot
COPY --from=build /src/SBFspot/date_time_zonespec.csv /usr/bin/sbfspot/date_time_zonespec.csv
COPY --from=build /src/SBFspot/TagListEN-US.txt /usr/bin/sbfspot/TagListEN-US.txt

# The program, as one executable: it takes files and paths, so there is nothing else to install.
COPY --from=build /src/sbfspot-mqtt/bin/sbfspot-mqtt /usr/bin/sbfspot-mqtt
RUN chmod a+x /usr/bin/sbfspot-mqtt

# Build-time smoke test. `-version` prints the version and exits 0; the `|| true` is there so that a
# later upstream release which changes that cannot fail the build for the wrong reason. What is
# being checked is the output: a binary that cannot resolve its libraries prints nothing here.
RUN set -e; \
    version="$(/usr/bin/sbfspot/SBFspot -version || true)"; \
    if [ -z "${version}" ]; then \
        echo "SBFspot did not run in this image: check the runtime libraries above." >&2; \
        exit 1; \
    fi; \
    echo "SBFspot ${version} built into the image"
RUN ! ldd /usr/bin/sbfspot/SBFspot | grep -q 'not found'

# And the same for the program: it is fetched from another repository, so "did the pin actually
# bring something runnable" is worth asking here rather than on a Raspberry Pi.
RUN set -e; \
    version="$(/usr/bin/sbfspot-mqtt version)"; \
    case "${version}" in \
        "${SBFSPOT_MQTT_REF#v}") echo "sbfspot-mqtt ${version} built into the image" ;; \
        *) echo "sbfspot-mqtt ${version} does not match the pinned ${SBFSPOT_MQTT_REF}" >&2; exit 1 ;; \
    esac

COPY rootfs /

# The executable bits come from the checkout, and a checkout that lost them (an archive, a copy
# through a filesystem that does not keep them) would build an image whose service never starts.
RUN chmod a+x /etc/services.d/sbfspot-mqtt/run /etc/services.d/sbfspot-mqtt/finish
