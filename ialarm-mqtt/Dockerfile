
ARG BUILD_FROM=ghcr.io/hassio-addons/base:12.2.6
FROM $BUILD_FROM

ENV LANG C.UTF-8

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /tmp

# Install requirements for add-on
RUN \
    apk add --no-cache \
        git \
        nodejs \
        npm \
    \
    && npm config set unsafe-perm true 

# clone version
WORKDIR  /app
RUN git clone --depth 1 --branch  v0.12.4  https://github.com/Stinocon/ialarm-mqtt.git

#install deps
WORKDIR  /app/ialarm-mqtt
RUN npm install \
        --no-audit \
        --no-optional \
        --no-update-notifier \
        --only=production \
        --unsafe-perm \
    \
    && rm -fr \
        /root/.cache \
        /root/.npm \
        /root/.nrpmrc \
        /tmp/*        

COPY rootfs /