# hack Directory

This directory contains useful scripts.

## Contents

- **cleanup_k8up_jobs.sh** cleanup stucked k8up jobs
- **generate_renovate_app_scopes.sh** generates Renovate app-scoped package rules for Docker updates
- **generate_kustomizations.sh** generates `kustomization.yaml` files
- **generate_secret_template.sh** generates `secret.template` files for SOPS-encrypted Kubernetes secrets
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

## generate_kustomizations

```console
Usage: generate_kustomizations.sh [-i|--ignore-folders "FOLDER, ..."]
                                  | [-h|--help]
                                  FOLDER [FOLDER ...]

Iterates recursively over each FOLDER and generates or updates
resources in the corresponding 'kustomization.yaml' files.
If a 'kustomization.yaml' has the key 'patchesStrategicMerge', the corresponding
'kustomization.yaml' will not be updated.

positional arguments:
FOLDER [FOLDER ...]                      one or more directories to iterate over recursively

optional parameters:
-i, --ignore-folders "[Folder] ..."      folders which should be skipped
                                         list of strings, separatet by a comma (case sensitive!)
-f, --flux-system-folder                 skip updating flux-system kustomization.yaml
-h, --help                               display this help and exit
```

## generate_secret_templates

```console
Usage: generate_secret_template.sh [-f|--force]
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
Scopes come from the app.kubernetes.io/name label in deployment/statefulset/daemonset manifests.
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
