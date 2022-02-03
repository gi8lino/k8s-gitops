#!/bin/bash
set -o errexit
set -o nounset

function healthchecks {
  [ -n "${HEALTHCHECKS_URL}" ] &&
    curl -fsS "${HEALTHCHECKS_URL}$([ "${1}" != 0 ] && echo -n /fail)" > /dev/null
}

function notify {
  healthchecks 1
  echo "ERROR: Unable to fetch firewall events!"
}

trap notify ERR

[ -z "${ZONE_ID}" ] && \
  echo "ERROR: ZONE_ID is not set!" && \
  healthchecks 1 && \
  exit 1
[ -z "${AUTH_TOKEN}" ] && \
  echo "ERROR: AUTH_TOKEN is not set!" && \
  healthchecks 1 && \
  exit 1

DEBUG=${DEBUG:-false}
INDEX_NAME=${INDEX_NAME:-cloudflare_fw_events}
ELASTIC_FQDN=${ELASTIC_FQDN:-http://elasticsearch.cloudflare.svc.cluster.local:9200}
ELASTIC_FQDN=${ELASTIC_FQDN%/}  # remove ending slash
MINUTES=${MINUTES:-6}
[ -n "${MINUTES##*[0-9]*}" ] && \
  echo "MINUTES must be INT" && \
  healthchecks 1 && \
  exit 1

END_DATE=${END_DATE:-$(date --date today +'%Y-%m-%d %H:%M:%S')}
start_date=$(date --date "${END_DATE} ${MINUTES} minutes ago" +'%Y-%m-%dT%H:%M:%SZ')
end_date=$(date --date "${END_DATE}" +'%Y-%m-%dT%H:%M:%SZ')

PAYLOAD='{ "query":
  "query {
    viewer {
      zones(filter: { zoneTag: $zoneTag }) {
      firewallEventsAdaptive(
        filter: $filter
        limit: 10000
        orderBy: [datetime_DESC, rayName_DESC]
      ) {
          action
          ruleId
          rayName
          clientAsn
          clientCountryName
          clientIP
          clientRequestPath
          clientRequestHTTPHost
          clientRequestQuery
          clientRefererHost
          clientRequestScheme
          edgeResponseStatus
          originResponseStatus
          datetime
          source
          userAgent
        }
      }
    }
  }",'

PAYLOAD="$PAYLOAD
  \"variables\": {
    \"zoneTag\": \"$ZONE_ID\",
    \"filter\": {
      \"datetime_gt\": \"$start_date\",
      \"datetime_leq\": \"$end_date\"
    }
  }
}"

[ "$DEBUG" == "true" ] && \
  echo "DEBUG: Cloudflare payload query: ${PAYLOAD}"

cf_response=$(curl \
  --silent \
  --show-error \
  --max-time 10 \
  --retry 3 \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${AUTH_TOKEN}" \
  --data "$(echo $PAYLOAD)" \
  https://api.cloudflare.com/client/v4/graphql/)

[ -n "$(jq '.errors[]?' <<< ${cf_response})" ] && \
  echo "ERROR: cannot get Cloudflare firewall events. $(jq '.errors[]?' <<< ${cf_response})" && \
  healthchecks 1 && \
  exit 1

[ -z "$(jq '.data.viewer.zones[0].firewallEventsAdaptive[]?' <<< ${cf_response})" ] && \
  echo "INFO: no firewall events found" && \
  healthchecks 0 && \
  exit 0

# check if pipeline for user agent exists
pipeline_response=$(curl \
  --silent \
  --show-error \
  --max-time 5 \
  --retry 3 \
  --write-out "%{http_code}" \
  --output /dev/null \
  ${ELASTIC_FQDN}/_ingest/pipeline/user_agent?pretty)

[ "$DEBUG" == "true" ] && \
  echo "DEBUG: user agent response: $(jq . <<< ${pipeline_response})"

if [ "${pipeline_response}" == 404 ]; then
  query='{
          "description": "Add user agent information",
          "processors": [
            {
              "user_agent": {
                "field": "userAgent"
              }
            }
          ]
        }'
  pipeline_response=$(curl \
    --silent \
    --show-error \
    --max-time 5 \
    --retry 3 \
    --header "Content-Type: application/json" \
    --request PUT \
    --data "$(echo $query)" \
    "${ELASTIC_FQDN}/_ingest/pipeline/user_agent?pretty")

  [ "$(jq '.acknowledged?' <<< ${pipeline_response})" != true ] && \
    echo "ERROR: cannot create pipeline. $(jq '.error?' <<< ${pipeline_response})" && \
    healthchecks 1 && \
    exit 1
fi

elastic_response=$(curl \
  --silent \
  --show-error \
  --max-time 10 \
  --retry 5 \
  --request POST \
  --header "Content-Type: application/x-ndjson" \
  --data-binary @<(jq -c '.data.viewer.zones[0].firewallEventsAdaptive[] | {"index":{"_id": .rayName}},  .' <<< ${cf_response}) \
  ${ELASTIC_FQDN}/${INDEX_NAME}/_bulk?pipeline=user_agent)

[ "$DEBUG" == "true" ] && \
  echo "DEBUG: elasticsearch response: $(jq . <<< ${elastic_response})"

healthchecks 0
