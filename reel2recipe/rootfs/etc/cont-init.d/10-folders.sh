#!/command/with-contenv bashio
# Prepares the folders on /data before the services start.
#
# Why here and not inside the two services: if each created them on its own account, the
# start-up order would decide who creates them, and the day that order changes it would turn
# into a fault to work out. Better once, before everybody.
set -e

for folder in /data/workspace /data/workspace/media /data/ollama /data/whisper; do
    mkdir -p "${folder}"
done

bashio::log.info "Persistent data in /data (library, models, downloaded media)."

# An honest warning instead of a mute fault: the cookie file is for the reels that require
# being logged in, and if the path is wrong you only find out on the first link.
if bashio::config.has_value 'file_cookie'; then
    cookie_file="/share/$(bashio::config 'file_cookie')"
    if [ -f "${cookie_file}" ]; then
        bashio::log.info "Cookies read from ${cookie_file}."
    else
        bashio::log.warning "file_cookie points at ${cookie_file}, which does not exist: the reels that require being logged in will fail."
    fi
fi
