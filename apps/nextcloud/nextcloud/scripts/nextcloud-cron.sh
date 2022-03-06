#!/usr/bin/env bash

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
            --fail \
            --location \
            --write-out "%{http_code}" \
            --output /dev/null \
            --header "Host: ${NEXTCLOUD_DOMAIN}" \
            "${NEXTCLOUD_CRON_URL}")

[ "${response}" != "200" ] && \
  HEALTHCHECKS_URL="${HEALTHCHECKS_URL}/fail"

curl \
  --fail \
  --silent \
  --show-error \
  --max-time 10 \
  --retry 5 \
  --output /dev/null \
  "${HEALTHCHECKS_URL}"
