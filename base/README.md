# base Directory

This directory contains applications that are useful for cluster operations.

## Contents

- **intel-gpu-plugin** Intel device plugin for Kubernetes
- **k8up** is a Kubernetes backup operator created by VSHN
- **minio** s3 compatible object storage for backups created by K8up
- **monitoring** contains kube-prometheus-stack and prometheus-pushgateway for cluster monitoring
- **reloader** is a Kubernetes controller to watch changes in ConfigMap and Secrets and do rolling upgrades on Pods with their associated Deployment, StatefulSet, DaemonSet and DeploymentConfig
- **syncflaer** synchronizes Traefik host rules with Cloudflare
