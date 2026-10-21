# apps Directory

This directory contains infrastructure applications.

## Contents

- **cert-manager** automatically provisions and manages TLS certificates in Kubernetes
- **cilium** is a CNI plugin that provides networking, security services, and bare-metal L2 load balancing
- **cloudflare-operator** Kubernetes operator for managing Cloudflare DNS records
- **cloudnative-pg** Kubernetes operator for managing PostgreSQL databases
- **debug** tools for debugging the cluster
- **filebrowser** browse files from the web
- **garage** S3-compatible backup storage and its management UI
- **gitlab** contains gitlab and other gitlab related applications
- **healthchecks** observability regularly running tasks such as cron jobs
- **k8up** is a Kubernetes backup operator created by VSHN
- **keycloak** identity and access management
- **kube-system** contains essential system components
- **kumbuka** self-hosted wiki for internal documentation
- **media** usenet-stack containing plex, prowlarr, radarr, sabnzbd, sonarr and tautulli
- **network** deploys Envoy Gateway for Gateway API-based ingress with dedicated internal/external data planes
- **nextcloud** self-hosted cloud similar to iCloud
- **observability** contains kube-prometheus-stack and prometheus-pushgateway for cluster observability
- **reloader** is a Kubernetes controller to watch changes in `ConfigMap` and `Secret` and do rolling upgrades on Pods with their associated `Deployments`, `Daemonsets` `Statefulsets` and `Rollouts`
- **renovate** dependency updater
- **storage** contains tools about storage
