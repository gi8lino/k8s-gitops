#!/usr/bin/env bash

set -o errexit

[[ "${PWD}" =~ "k8s-gitops/hack" ]] && \
  echo "please cd to the root folder and run the script from there!" && \
  exit 1

KUSTOMIZATION_TEMPLATE="---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:"

NOFORMAT='\033[0m'
GREEN='\033[0;32m'

ShowHelp() {
    printf "
Usage: generate_kustomizations.sh [-i|--ignore-folders \"FOLDER, ...\"]
                                  | [-h|--help]
                                  FOLDER [FOLDER ...]

Iterates recursively over each FOLDER and generates or updates
resources in the corresponding 'kustomization.yaml' files.

positional arguments:
FOLDER [FOLDER ...]                      one or more directories to iterate over recursively

optional parameters:
-i, --ignore-folders \"[Folder] ...\"      folders which should be skipped
                                         list of strings, separatet by a comma (case sensitive!)
-h, --help                               display this help and exit
\n"
    exit 0
}

while [ $# -gt 0 ]; do
    key="$1"
    case $key in
        -i|--ignore-folders)
        IFS=',' read -r -a IGNORE_FOLDERS <<< "$2"
        shift
        shift
        ;;
        -h|--help)
        ShowHelp
        ;;
        *)
        BASE_FOLDERS+=("$key")
        shift
        ;;
    esac
done

function process_folder {
  pushd "${1}" > /dev/null
  printf "processing: ${GREEN}$(pwd)${NOFORMAT}\n"

  readarray -d '' folders < <(find . -type d -maxdepth 1 -mindepth 1 $(printf "! -name %s " ${IGNORE_FOLDERS[@]}) -execdir printf '%s\n' {} +)
  readarray -d '' files < <(find . -type f -maxdepth 1 -mindepth 1 -name "*.yaml" -not -name "kustomization.yaml" -execdir printf '%s\n' {} +)

  [[ -z "${files}" && -z "${folders}" ]] && \
    popd > /dev/null && \
    return

  [[ ! -f "kustomization.yaml" ]] && \
    echo "${KUSTOMIZATION_TEMPLATE}" > kustomization.yaml

  resources="${folders} ${files}"  # merge arrays
  resources=$(printf '"%s", ' ${resources[@]})  # add quotes to values and convert array to a string, separated by comma

  yq eval \
      --inplace \
      ".resources = [ ${resources%,*} ]" \
      kustomization.yaml

  [[ -z "${folders}" ]] && \
    popd > /dev/null && \
    return

  for folder in ${folders}; do
    process_folder "${folder}"
  done

  popd > /dev/null
}

[ -z "${BASE_FOLDERS[@]}" ] && \
  echo "ERROR: no base folder given!" && \
  exit 1

for base_folder in "${BASE_FOLDERS[@]}"; do
  process_folder "${base_folder}"
done

git checkout -- core/flux-system/kustomization.yaml
