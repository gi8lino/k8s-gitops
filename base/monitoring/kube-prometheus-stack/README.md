# kube-prometheus-stack

## todo

wait until prometheus-operator can handle alertmanager > 22.  
then update following config:

```yaml
alertmanager:
    route:
      routes:
        - receiver: slack
          mute_time_intervals:
            - business_hours
            - weekend
```

## :hugs:&nbsp; Thanks

link to original dashboard:

- [node-exporter-full](https://grafana.com/grafana/dashboards/10242)
