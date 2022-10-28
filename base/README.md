# base Directory

This directory contains applications that are useful for cluster operations.

## Contents

- **cloudflare-operator** manage Cloudflare DNS records using Kubernetes objects
- **intel-gpu-plugin** Intel device plugin for Kubernetes
- **k8up** is a Kubernetes backup operator created by VSHN
- **minio** s3 compatible object storage for backups created by K8up
- **monitoring** contains prometheus related tools and objects
- **reloader** is a Kubernetes controller to watch changes in `ConfigMap` and `Secret` and do rolling upgrades on Pods with their associated `Deployments`, `Daemonsets` `Statefulsets` and `Rollouts`
