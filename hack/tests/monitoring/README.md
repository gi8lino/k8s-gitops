# Monitoring rule checks

Run `PROMTOOL=/path/to/promtool hack/test_monitoring_rules.sh` with Prometheus 3.x and Mike Farah's `yq` installed. The script extracts the Kubernetes rule groups into a temporary directory before invoking promtool.

Backup monitoring reads K8up and CNPG Backup objects through kube-state-metrics. It distinguishes successful completion from a Job merely starting, detects objects stuck before Job creation, and ignores terminal failures in the stuck-object alert. A failure never advances the last-success timestamp.

Every Schedule/ScheduledBackup declares `monitoring.gitops/backup-max-age-seconds`. Current deadlines allow 14 hours for a twice-daily schedule, 26 hours for daily schedules, and 8 days for weekly schedules. New schedules get their first deadline from their creation time; schedules without a deadline raise a configuration alert. These annotations change monitoring only, not backup frequency or retention.

When adding a backup schedule, set its deadline and extend the rule tests if its cadence introduces a new policy. Existing failed backup objects are retained; they do not become permanently stuck alerts.

Blackbox rules compare observed probe results with the URLs declared in ServiceMonitor objects. One vanished target cannot be masked by healthy targets, and loss of the target-inventory collector raises its own alert. A recovered probe clears the failure condition; one isolated failure is not treated as a sustained outage.
