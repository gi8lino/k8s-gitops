# hack Directory

This directory contains useful scripts.

## Contents

- **cleanup_k8up_jobs.sh** cleanup stucked k8up jobs
- **generate_renovate_app_scopes.sh** generates Renovate app-scoped package rules for Docker updates
- **`task hack:k`** generates `kustomization.yaml` files with `kustomizer`
- **generate_secret_templates.sh** generates `secret.template` files for SOPS-encrypted Kubernetes secrets
- **list_helmrelease_namespaces.sh** prints namespaces used by HelmRelease manifests
- **update_slack_helmrelease_alert.sh** updates HelmRelease alert eventSources with discovered namespaces

## cleanup_k8up_jobs

```console
Usage: cleanup_k8up_jobs.sh [-A|--all-namespaces]
                            [-h|--help]

Searches for pods in current namespace with status 'Terminating' and label
'k8upjob', delete the related job and remove the finalizer of the pod so
the pod will be deleted.

-A, --all-namespaces   search in all namespaces for pod with status 'Terminating'
-h, --help             display this help and exit
```

## generate kustomizations

```console
task hack:k
```

Runs `kustomizer` across the `cluster` tree while excluding generated and
configuration-only directories.

## generate_secret_templates

```console
Usage: generate_secret_templates.sh [-f|--force]
                                    | [-h|--help]

Generates 'secret.template' files for SOPS-encrypted Kubernetes secrets.
Unencrypted secret will be automatically decrypted!

-f, --force         override existing templates
-h, --help          display this help and exit
```

## generate_renovate_app_scopes

```console
Usage: generate_renovate_app_scopes.sh [OUTPUT_FILE]

Builds .github/renovate/appScopes.json5 with per-app Docker scope rules.
Scopes come from workload labels and HelmRelease metadata under `cluster/apps`
and `cluster/infra`.
```

## list_helmrelease_namespaces

```console
Usage: list_helmrelease_namespaces.sh [PATH ...]

Prints the unique namespaces used by HelmRelease manifests under the given
paths (defaults to ./cluster).
```

## update_slack_helmrelease_alert

```console
Usage: update_slack_helmrelease_alert.sh --alert-file ALERT_FILE [PATH ...]

Finds HelmRelease manifests under the given paths (defaults to ./cluster),
collects their namespaces, and updates the HelmRelease Alert eventSources
in the provided ALERT_FILE.
```

## schema

Iterates over each ".yaml" file and tries to add the yaml-schema to the file.
