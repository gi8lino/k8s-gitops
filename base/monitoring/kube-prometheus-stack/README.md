# kube-prometheus-stack

## todo

wait until prometheus-operator can handle alertmanager > 22.  
then update following config:

```yaml
alertmanager:
  mute_time_intervals:
    - name: business_hours
      time_intervals:
        - weekdays: ['monday:friday']
          times:
            - start_time: 00:00
              end_time: 07:30
    - name: weekend
      time_intervals:
        - weekdays: ['saturday','sunday']
          times:
            - start_time: 00:00
              end_time: 09:00
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
