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
| `MINUTES`                           | Minutes to subtract from `now`                                                       | 60                   |

## Grafana dashboard

You can find an example of a Grafana Dashboard here:

https://raw.githubusercontent.com/gi8lino/grafana-dashboards/master/Cloudflare-Firewall-Events.json
