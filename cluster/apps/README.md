# apps Directory

This directory contains infrastructure applications.

## Contents

- **cert-manager** automatically provisions and manages TLS certificates in Kubernetes
- **cilium** is a CNI plugin that provides networking and security services
- **cloudflare-operator** Kubernetes operator for managing Cloudflare DNS records
- **cloudnative-pg** Kubernetes operator for managing PostgreSQL databases
- **debug** tools for debugging the cluster
- **falco** is a runtime security tool that detects abnormal behavior
- **filebrowser** browse files from the web
- **gitlab** contains gitlab and other gitlab related applications
- **healthchecks** monitoring regularly running tasks such as cron jobs
- **ingress-nginx** is an Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer
- **k8up** is a Kubernetes backup operator created by VSHN
- **keycloak** identity and access management
- **kube-system** contains essential system components
- **media** usenet-stack containing plex, prowlarr, radarr, sabnzbd, sonarr and tautulli
- **metallb** MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols
- **minio** s3 compatible object storage
- **monitoring** contains kube-prometheus-stack and prometheus-pushgateway for cluster monitoring
- **nextcloud** self-hosted cloud similar to iCloud
- **oauth2-proxy** is an OAuth2 proxy that provides authentication with Google, GitHub, and others
- **reloader** is a Kubernetes controller to watch changes in `ConfigMap` and `Secret` and do rolling upgrades on Pods with their associated `Deployments`, `Daemonsets` `Statefulsets` and `Rollouts`
- **renovate** dependency updater
- **storage** contains tools about storage
- **vimbin** self-hosted pastebin for with vim motions
- **wiki** self-hosted wiki for internal documentation
