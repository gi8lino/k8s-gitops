# Cloudflare Firewall Events

Fetches Cloudflare Firewall events for the configured time period (defaults from (now minus 60 minutes) until now) and store them in a Elasticsearch database.

You have to pass an Cloudflare API token to the cronjob.
To create an API token see [here](https://developers.cloudflare.com/analytics/graphql-api/getting-started/authentication/api-token-auth)

## environment variables

You can set following environment variables to override the default behavior of the script:

| parameter                           | description                                                                          | default              |
| :---------------------------------- | :----------------------------------------------------------------------------------- | :------------------- |
| `DEBUG`                             | output curl responses                                                                | false                |
| `INDEX_NAME`                        | name of elasticsearch index to add firewall events                                   | cloudflare_fw_events |
| `ELASTIC_FQDN`                      | FQDN of elasticsearch                              | http://elasticsearch.cloudflare.svc.cluster.local:9200 |
| `END_DATE`                          | end date of time range to fetch Cloudflare firewall events                           | today                |
| `MINUTES`                           | Minutes to subtract from `END_DATE`. Will be used as start date of time range to fetch Cloudflare firewall events                                                                                     | 60                   |
| `HEALTHCHECKS_URL`                  | ping healthchecks after the firewall events are fetched and stored in elasticsearch  | NONE                 |

## Grafana dashboard

Add `Cloudflare-Firewall-Events.json` to grafana for a nice dashboard

## load old Cloudflare data

In Cloudflare free-plan time range can be maximum 1440 minutes and go maxium 14 days back.

### one day back

kubectl create job \
    --namespace=cloudflare \
    --from=cronjob/cloudflare-cron manual-cron-one-day-back \
    --dry-run=client \
    -ojson | \
  jq ".spec.template.spec.containers[0].env += [{ \"name\": \"MINUTES\", value: \"1440\" }]" | \
  kubectl apply -f -

### 14 days back

The script will create for each of day of the last past 14 days a cronjob.

```bash
for ((i=1;i<=14;i++)); do
  TODAY=$(date --date today +'%Y-%m-%d %H:%M:%S')
  MINUTES=$(( ${i} * 1440 ))
  end_date=$(date --date "${TODAY} ${MINUTES} minutes ago" +'%Y-%m-%dT%H:%M:%SZ')
  job_name=manual-cloudflare-cron-$(date --date "${TODAY} ${MINUTES} minutes ago" +'%Y-%m-%d')

  kubectl create job \
    --namespace=cloudflare \
    --from=cronjob/cloudflare-cron ${job_name} \
    --dry-run=client \
    -ojson | \
  jq ".spec.template.spec.containers[0].env += [{ \"name\": \"END_DATE\", value: \"${end_date}\" }]" | \
  kubectl apply -f -
done
```
