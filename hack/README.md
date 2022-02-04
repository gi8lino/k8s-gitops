# hack Directory

This directory contains useful scripts.

## Contents

- **cleanup_k8up_jobs.sh** cleanup stucked k8up jobs
- **generate_kustomizations.sh** generates `kustomization.yaml` files
- **generate_secret_template.sh** generates `secret.template` files for SOPS-encrypted Kubernetes secrets

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
