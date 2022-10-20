#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# cleanup pid if it exists
[[ -e /config/sonarr.pid ]] && \
    rm -rf /config/sonarr.pid

# because an nfs share is mounted to '/config/backups' and there are problems with permissions,
# set ownership to all other files & directories recursively
find /config \
    -mindepth 1 \
    -maxdepth 1 \
    -not -path /config/Backups \
    -exec chown -R abc:abc {} +
