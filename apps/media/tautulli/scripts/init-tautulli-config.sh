#!/usr/bin/with-contenv bash

# permissions
chown -R abc:abc \
    /app

find /config \
    -maxdepth 1 \
    -not -path /config/backups \
    -exec chown -R abc:abc {} +
