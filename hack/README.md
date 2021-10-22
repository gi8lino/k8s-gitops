# hack Directory

This directory contains useful scripts that are mostly bodgy at best.

## Contents

- **generate_kustomizations.sh** generates `kustomization.yaml` files
- **generate_secret_template.sh** generates `secret.template` files for SOPS-encrypted Kubernetes secrets

## generate_kustomizations

```console
Usage: generate_kustomizations.sh [-i|--ignore-folders "FOLDER, ..."]
                                  | [-h|--help]
                                  FOLDER [FOLDER ...]

Iterates recursively over each FOLDER and generates or updates
resources in the corresponding 'kustomization.yaml' files.

positional arguments:
FOLDER [FOLDER ...]                      one or more directories to iterate over recursively

optional parameters:
-i, --ignore-folders "[Folder] ..."      folders which should be skipped
                                         list of strings, separatet by a comma (case sensitive!)
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
