# apps/gitlab Directory

This directory contains gitlab related objects.
contains GitLab, its dedicated Garage object store, ingress, and gitlab-runner.

GitLab application backups use the `gitlab-backups` bucket in the separate
`garage-backup` instance. The `gitlab-tmp` bucket there is reserved for restores.
PostgreSQL WAL and base backups use `gitlab-db-backups` in the same instance.
GitLab's active application object storage remains in `gitlab-garage`.

The toolbox keeps separate S3 configurations for active data and backups. When
restoring an application backup, pass
`--s3config /etc/gitlab/backup-object-storage.s3cfg` to `backup-utility`, alongside
`--backend-data s3 --backend-backup s3 --s3tool-data s3cmd --s3tool-backup s3cmd`,
so it reads the backup archive from Garage backup storage rather than the active
object store. Restores overwrite application data and must be planned separately.

## Contents

- **garage** contains garage objects
- **gitlab-runner** runs GitLab CI/CD jobs in a pipeline
- **gitlab** contains gitlab objects
- **postgres** contains postgres objects
- **valkey** contains valkey objects
