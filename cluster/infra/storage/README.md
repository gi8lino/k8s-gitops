# storage-system Directory

This directory contains storage related applications.

## Contents

- **local-path-provisioner** dynamically provisions persistent local storage with Kubernetes
- **nfs-subdir-external-provisioner** dynamically provisions sub-dirs on a remote NFS server

## Retired MinIO data

MinIO was retired after migrating GitLab application backups to Garage. Its
500 Gi NFS volume, `pvc-bf432d71-843d-4a50-863a-7569e9fc2d9e`, has a `Retain`
reclaim policy so uninstalling MinIO does not delete historical backup data.
The data remains on `nfs.srv.${BASE_DOMAIN}` at
`/volume1/backup/kubernetes/minio-minio-pvc-bf432d71-843d-4a50-863a-7569e9fc2d9e`.
Do not delete the retained volume or NFS directory until its old backups are no
longer required. MinIO's previous deployment and encrypted configuration can be
recovered from Git history if access to the retained data is needed.
