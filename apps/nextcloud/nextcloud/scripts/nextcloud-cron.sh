#!/usr/bin/env bash

# execute a curl command to trigger nextcloud cron.php and afterwards ping healthchecks
# to update cronjob status
# nextcloud cron.php description:
# https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html#cron-jobs

set -o errexit

HEALTHCHECKS_URL=${HEALTHCHECKS_URL%*/}
NEXTCLOUD_CRON_URL=${NEXTCLOUD_CRON_URL:-http://nextcloud.nextcloud.svc.cluster.local/cron.php}

[ -z "${HEALTHCHECKS_URL}" ] && \
  echo "'HEALTHCHECKS_URL' is not set!" && \
  exit 1

[ -z "${NEXTCLOUD_DOMAIN}" ] && \
  echo "'NEXTCLOUD_DOMAIN' is not set!" && \
  exit 1

response=$(curl \
            -sS \
            --location \
            --write-out "%{http_code}" \
            --output /dev/null \
            --header "Host: ${NEXTCLOUD_DOMAIN}" \
            "${NEXTCLOUD_CRON_URL}")

[ "${response}" != "200" ] && \
  HEALTHCHECKS_URL="${HEALTHCHECKS_URL}/fail"

curl \
  -sS \
  --max-time 10 \
  --retry 5 \
  --output /dev/null \
  "${HEALTHCHECKS_URL}"

# -f: Makes curl treat non-200 responses as errors.
# -s: Silent or quiet mode. Hides the progress meter, but also hides error messages.
# -S: Re-enables error messages when -s is used.
