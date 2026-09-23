# Deliberately without a default, for the same reason as ezviz-stream-bridge: this add-on's
# bases are architecture-specific (`{arch}-base-debian`), and the builder action does not pass
# BUILD_FROM by itself. A default here would quietly give one architecture the other one's base
# image. The value comes from build.yaml, per architecture, passed by the workflows.
ARG BUILD_FROM
FROM ${BUILD_FROM} AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The same tag the release is cut from, and the only place the *build* refers to it: the README
# and the changelog name the version too, as prose that nothing keeps in sync, and this is the
# line that decides what actually gets compiled. One version to bump where it matters.
ARG SBFSPOT_REF="V3.9.12"

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

# `nosql` and not `sqlite`/`mariadb`: this add-on publishes to MQTT and keeps no history of its
# own. Home Assistant already records the states it cares about, and a second database inside
# the container would be a second thing to back up, migrate and explain. Upstream's makefile
# documents the four flavours; the binary lands in nosql/bin/.
RUN make -C ./SBFspot nosql


FROM ${BUILD_FROM} AS runtime

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The runtime libraries are named here, version and all, because Debian's boost runtime
# packages are versioned and there is no unversioned metapackage to depend on. The `ldd` guard
# below turns a wrong guess into a failed build instead of a container that starts and dies at
# the first poll with "error while loading shared libraries" -- and the author of that message
# is nobody's friend.
#
# mosquitto-clients is not optional: SBFspot shells out to a mosquitto client to publish, and
# without one it reports the failure and drops the reading.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libbluetooth3 \
        libboost-date-time1.83.0 \
        libboost-system1.83.0 \
        libstdc++6 \
        mosquitto-clients \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# TagDefs reads TagList<LOCALE>.txt next to the executable, and falls back to EN-US when the
# file for the configured locale is missing. The generated config pins Locale=en-US, so only
# that one is shipped: the other five are ~450 KB each for a fallback that cannot trigger.
COPY --from=build /src/SBFspot/nosql/bin/SBFspot /usr/bin/sbfspot-mqtt/SBFspot
COPY --from=build /src/SBFspot/date_time_zonespec.csv /usr/bin/sbfspot-mqtt/date_time_zonespec.csv
COPY --from=build /src/SBFspot/TagListEN-US.txt /usr/bin/sbfspot-mqtt/TagListEN-US.txt

# Build-time smoke test. `-version` prints the version and exits 0; the `|| true` is there so
# that a later upstream release which changes that cannot fail the build for the wrong reason.
# What is being checked is the output: a binary that cannot resolve its libraries prints nothing
# here.
RUN set -e; \
    version="$(/usr/bin/sbfspot-mqtt/SBFspot -version || true)"; \
    if [ -z "${version}" ]; then \
        echo "SBFspot did not run in this image: check the runtime libraries above." >&2; \
        exit 1; \
    fi; \
    echo "SBFspot ${version} built into the image"
RUN ! ldd /usr/bin/sbfspot-mqtt/SBFspot | grep -q 'not found'

COPY rootfs /

# The executable bits come from the checkout, and a checkout that lost them (an archive, a copy
# through a filesystem that does not keep them) would build an image whose services never start.
RUN chmod a+x \
    /etc/services.d/sbfspot-mqtt/run \
    /etc/services.d/sbfspot-mqtt/finish \
    /usr/bin/sbfspot-mqtt/discovery.sh \
    /usr/bin/sbfspot-mqtt/generate-config.sh \
    /usr/bin/sbfspot-mqtt/mqtt-pub.sh \
    /usr/bin/sbfspot-mqtt/publish.sh
