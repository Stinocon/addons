# Deliberately without a default, unlike the other add-ons in this repository.
#
# They can afford one: ialarm-mqtt uses a multi-arch manifest, so the same reference is right
# on both architectures, and reel2recipe is amd64-only. This add-on is the first here that is
# multi-arch on *architecture-specific* base images, and there a default is a trap: the builder
# action does not pass BUILD_FROM unless the workflow asks it to, so the default quietly wins
# and one of the two architectures gets the other one's base image. That is exactly what
# happened on the first build — an aarch64 base pulled on an x86 runner, failing at the first
# RUN with exit 255 and an error naming neither the architecture nor the image.
#
# With no default, a missing BUILD_FROM fails immediately and says the base name is empty.
# The value comes from build.yaml, passed per architecture by the workflow's `build-args`.
ARG BUILD_FROM
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Debian and not Alpine: pyezvizapi pulls in `cryptography` and `pycryptodome`, which ship
# manylinux (glibc) wheels. On musl there are no binaries for either, and the build would
# compile Rust and C from source on every architecture.

ARG BUILD_ARCH=aarch64
# Pinned, not floating: the service below depends on the flags of `pyezvizapi stream proxy`,
# and the assertions further down check they are still there. A surprise rename would
# otherwise turn into an add-on that restarts forever with an argparse error.
ARG PYEZVIZAPI_VERSION="1.0.5.0"
ARG BRIDGE_REF="main"

ENV \
    LANG="C.UTF-8" \
    VIRTUAL_ENV="/opt/venv" \
    PATH="/opt/venv/bin:/usr/local/bin:/usr/bin:/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK="1" \
    PIP_NO_CACHE_DIR="1" \
    PIP_ROOT_USER_ACTION="ignore" \
    # Unbuffered, or the supervisor's log lines would sit in a pipe buffer and reach the
    # add-on log minutes late -- exactly when somebody is watching it to see what broke.
    PYTHONUNBUFFERED="1"

RUN \
    if [ "${BUILD_ARCH}" != "aarch64" ] && [ "${BUILD_ARCH}" != "amd64" ]; then \
        echo "Unsupported architecture: ${BUILD_ARCH}. See config.yaml." >&2; exit 1; \
    fi

# ffmpeg remuxes the camera payload into MPEG-TS with codec copy only -- it never
# transcodes, which is why this runs fine without a GPU. git fetches the bridge below.
RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        ffmpeg \
        git \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# A virtual environment rather than Debian's system Python: pip refuses to touch an
# externally-managed interpreter, and --break-system-packages is a promise this image
# cannot keep across base-image updates.
RUN python3 -m venv "${VIRTUAL_ENV}"

RUN pip install "pyezvizapi==${PYEZVIZAPI_VERSION}"

# ---------------------------------------------------------------------------------------
# The bridge
# ---------------------------------------------------------------------------------------
# Cache-bust: the content of this file changes on every commit, which invalidates the clone
# below. Without it BuildKit would reuse the cached layer and the add-on would quietly ship
# old code while reporting the new version.
ADD https://api.github.com/repos/Stinocon/ezviz-stream-bridge/commits/${BRIDGE_REF} /tmp/bridge-source.json

RUN \
    git clone --depth 1 --branch "${BRIDGE_REF}" \
        https://github.com/Stinocon/ezviz-stream-bridge.git /tmp/bridge \
    && pip install /tmp/bridge \
    && rm -rf /tmp/bridge /tmp/bridge-source.json

# ---------------------------------------------------------------------------------------
# What the image promises, checked while it is still being built
# ---------------------------------------------------------------------------------------
# Every one of these is something the running add-on would otherwise discover on a user's
# machine: a missing command, a renamed flag, an ffmpeg without the encoders. Failing here
# costs a red build; failing there costs a restart loop and an unreadable log.
RUN \
    ezviz-stream-bridge --help > /dev/null \
    && python3 -c "import ezviz_stream_bridge; print(ezviz_stream_bridge.__version__)" \
    && python3 -m ezviz_stream_bridge.proxy --help > /dev/null \
    && ffmpeg -hide_banner -version > /dev/null \
    && python3 -c "from pyezvizapi.cloud_stream import copy_cloud_stream_to_mpegts" \
    && python3 -c "from pyezvizapi.client import EzvizClient"

COPY rootfs /

ARG BUILD_VERSION
LABEL \
    io.hass.name="EZVIZ Stream Bridge" \
    io.hass.description="EZVIZ camera video as MPEG-TS for go2rtc and Frigate" \
    io.hass.arch="aarch64|amd64" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION}
