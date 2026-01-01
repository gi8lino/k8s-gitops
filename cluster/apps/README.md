# apps Directory

This directory contains infrastructure applications.

## Contents

- **cert-manager** automatically provisions and manages TLS certificates in Kubernetes
- **cilium** is a CNI plugin that provides networking, security services, and bare-metal L2 load balancing
- **cloudflare-operator** Kubernetes operator for managing Cloudflare DNS records
- **cloudnative-pg** Kubernetes operator for managing PostgreSQL databases
- **debug** tools for debugging the cluster
- **falco** is a runtime security tool that detects abnormal behavior
- **filebrowser** browse files from the web
- **gitlab** contains gitlab and other gitlab related applications
- **healthchecks** observability regularly running tasks such as cron jobs
- **network** deploys Envoy Gateway for Gateway API-based ingress with dedicated internal/external data planes
- **k8up** is a Kubernetes backup operator created by VSHN
- **keycloak** identity and access management
- **kube-system** contains essential system components
- **media** usenet-stack containing plex, prowlarr, radarr, sabnzbd, sonarr and tautulli
- **minio** s3 compatible object storage
- **observability** contains kube-prometheus-stack and prometheus-pushgateway for cluster observability
- **nextcloud** self-hosted cloud similar to iCloud
- **reloader** is a Kubernetes controller to watch changes in `ConfigMap` and `Secret` and do rolling upgrades on Pods with their associated `Deployments`, `Daemonsets` `Statefulsets` and `Rollouts`
- **renovate** dependency updater
- **storage** contains tools about storage
- **vimbin** self-hosted pastebin for with vim motions
- **wiki** self-hosted wiki for internal documentation
