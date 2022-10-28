#!/usr/bin/env bash

function send_healthchecks {
  local send_failed="${1:-false}"
  curl --retry 3 \
        --max-time 5 \
        --silent \
        --show-error \
        "${HEALTHCHECKS_URL}$([ "${send_failed}" = "true" ] && echo -n /fail)" > /dev/null
}

function notify {
  send_healthchecks true
  echo "ERROR: Unable to prune!"
}

trap notify ERR

[[ -z "${HEALTHCHECKS_URL}" ]] && echo "HEALTHCHECKS_URL is not set!" && exit 1

# Remove user accounts that match either of these conditions:
# Account was created more than 6 months ago, and user has never logged in. These can happen when user enters invalid email address when signing up.
# Last login was more than 6 months ago, and the account has no checks. Assume the user doesn't intend to use the account any more and would probably want it removed.
python3 /app/healthchecks/manage.py pruneusers

# Remove old records from the api_tokenbucket table. The TokenBucket model is used for rate-limiting login attempts and similar operations.
# Any records older than one day can be safely removed.
python3 /app/healthchecks/manage.py prunetokenbucket

# Remove old records from the api_flip table. The Flip objects are used to track status changes of checks, and to calculate downtime statistics month by month.
# Flip objects from more than 3 months ago are not used and can be safely removed.
python3 /app/healthchecks/manage.py pruneflips

# Remove old objects from external object storage. When an user removes a check, removes a project, or closes their account,
# Healthchecks does not remove the associated objects from the external object storage on the fly.
# Instead, you should run pruneobjects occasionally (for example, once a month). This command first takes an inventory of all checks in the database,
# and then iterates over top-level keys in the object storage bucket, and deletes any that don't also exist in the database.
python3 /app/healthchecks/manage.py pruneobjects

# Prune old pings
python3 /app/healthchecks/manage.py prunepings

# Prune old notifications
python3 /app/healthchecks/manage.py prunenotifications

# Shrink db
python3 -c 'import os; import sqlite3; con = sqlite3.connect(os.getenv("DB_NAME", "sqlite"), isolation_level=None); con.execute("VACUUM"); con.close()'

send_healthchecks false
