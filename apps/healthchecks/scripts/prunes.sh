#!/usr/bin/env bash

function send_healthchecks {
  local send_failed="${1}"
  curl --retry 3 \
        --max-time 5 \
        --silent \
        --show-error \
        "${HEALTHCHECKS_URL}$([ -n "${send_failed}" ] && echo -n /fail)" > /dev/null
}

function notify {
  send_healthchecks true
  echo "ERROR: Unable to prune!"
}

trap notify ERR

[[ -z "${HEALTHCHECKS_URL}" ]] && echo "HEALTHCHECKS_URL is not set!" && exit 1

python3 /app/healthchecks/manage.py prunepings
python3 /app/healthchecks/manage.py prunenotifications
python3 /app/healthchecks/manage.py pruneusers
python3 /app/healthchecks/manage.py prunetokenbucket
python3 /app/healthchecks/manage.py pruneflips

python3 -c 'import os; import sqlite3; con = sqlite3.connect(os.getenv("DB_NAME", "sqlite"), isolation_level=None); con.execute("VACUUM"); con.close()'

send_healthchecks
