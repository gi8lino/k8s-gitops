# apps/gitlab Directory

This directory contains gitlab related objects.
contains gitlab-backup-mirror (MirrIO), gitlab minio ingress and gitlab-runner

## Contents

- **gitlab** contains networkpolicies for GitLab, mail-password- & saml-sso-secret and IngressRouteTCP for GitLab ssh
- **gitlab-backup-mirror** synchronize GitLab backups with external minIO with MirrIO
- **gitlab-runner** runs GitLab CI/CD jobs in a pipeline
