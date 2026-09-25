# Deliberately without a default: the base is architecture-specific and the builder passes
# BUILD_FROM from build.yaml. A default would silently pick the wrong architecture's image.
ARG BUILD_FROM
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# node + npm build the TypeScript; git fetches the rethink fork; openssl generates the CA the
# server creates on first run (rethink-cloud.ts shells out to `openssl req`); jq renders the
# config in run.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        jq \
        nodejs \
        npm \
        openssl \
    && rm -rf /var/lib/apt/lists/*

# Pinned to the fork's own tag, not to a branch: the dishwasher work lives on the branch rebased
# onto rethink v0.1.0 (`v0.1.0-d0211`), while the fork's `master` is the older pre-rebase tree and
# would build without it. A tag also means a given add-on version always builds the same source.
ARG RETHINK_REF=v0.1.0-d0211

# Cache-bust: changing the ref above invalidates the clone layer below, so a rebuild picks up the
# new source instead of reusing the stale cloned layer.
ADD https://api.github.com/repos/Stinocon/rethink-dishwasher/commits/${RETHINK_REF} /tmp/rethink-source.json

RUN git clone --depth 1 --branch "${RETHINK_REF}" \
        https://github.com/Stinocon/rethink-dishwasher.git /opt/rethink

WORKDIR /opt/rethink
RUN npm ci --ignore-scripts \
    && npm run build \
    && npm prune --omit=dev \
    && npm cache clean --force

# The image promises a built server. Failing here is a red build; failing at runtime is a
# restart loop nobody sees coming.
RUN test -f /opt/rethink/dist/rethink-cloud.js \
    && node --version

COPY rootfs /

ARG BUILD_VERSION
LABEL \
    io.hass.name="rethink-cloud — LG Dishwasher" \
    io.hass.description="Local LG ThinQ cloud emulator (rethink fork) with LG dishwasher support" \
    io.hass.arch="aarch64|amd64" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION}
