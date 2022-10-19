#!/usr/bin/with-contenv bash

# permissions
chown -R abc:abc \
    /app

find /config \
    -not -path Backups \
    -exec chown abc:abc {} +
