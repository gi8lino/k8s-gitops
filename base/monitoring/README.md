# base/monitoring Directory

This directory contains monitoring apps.

## Contents

- **flux-system** contains monitoring objects for Flux. They need to be created afterwards since crds don't exist when `core` is being deployed.
- **kthxbye** is a simple daemon that will automatically extend expiring silences from Alertmanager
- **kube-prometheus-stack** is a collection of Kubernetes manifests, Grafana dashboards, and Prometheus rules
- **pihole-server** contains monitoring objects for a pihole server
- **prometheus-blackbox-exporter** is a blackbox prober exporter
- **prometheus-pushgateway** is a push acceptor for ephemeral and batch jobs
- **tools-server** contains monitoring objects for a tools server
