
ARG BUILD_FROM=ghcr.io/hassio-addons/base:14.1.3
FROM $BUILD_FROM

ENV LANG=C.UTF-8

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /tmp

# Install requirements for add-on. Node comes from the base image's Alpine
# release: base 12.x carried Alpine 3.16 and Node 16 (end of life since
# September 2023), base 14.x carries Alpine 3.18 and Node 18. No Home Assistant
# base image ships Node 20 or later yet.
RUN \
    apk add --no-cache \
        git \
        nodejs \
        npm

# clone version
WORKDIR  /app
# Cache-bust: this file's content changes whenever the source repo's master HEAD
# changes, which invalidates the git clone + npm install layers below. Without it
# BuildKit caches the clone and the add-on would ship stale code.
ADD https://api.github.com/repos/Stinocon/ialarm-mqtt/commits/master /tmp/ialarm-source.json
RUN git clone --depth 1 --branch master https://github.com/Stinocon/ialarm-mqtt.git

#install deps
WORKDIR  /app/ialarm-mqtt
# npm 9 (which ships with Node 18) dropped `unsafe-perm` and replaced
# `--only=production` with `--omit=dev`; the old spelling made the build fail
# outright rather than warn.
RUN npm install \
        --no-audit \
        --no-optional \
        --no-update-notifier \
        --omit=dev \
    \
    && rm -fr \
        /root/.cache \
        /root/.npm \
        /root/.nrpmrc \
        /tmp/*        

COPY rootfs /