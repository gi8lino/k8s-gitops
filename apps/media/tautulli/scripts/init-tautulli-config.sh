#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# permissions
chown -R abc:abc \
    /app

# because an nfs share is mounted to '/config/backups' and there are problems with permissions,
# set ownership to all other files & directories recursively
# '-not -path /config' is ignored to prevent error when setting ownership to '/config' recursively
find /config \
    -maxdepth 1 \
    -not -path /config \
    -not -path /config/backups \
    -exec chown -R abc:abc {} +
