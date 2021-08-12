#!/usr/bin/env bash

set -o errexit

[[ "${PWD}" =~ "k8s-gitops/hack" ]] && echo "please cd to the root folder and run the script from there!" && exit 1

KUSTOMIZATION_TEMPLATE="---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:"

declare -a BASE_FOLDERS

BASE_FOLDERS+=("apps")
BASE_FOLDERS+=("base")
BASE_FOLDERS+=("core")
BASE_FOLDERS+=("crds")
BASE_FOLDERS+=("infra")

function process_folder {
  pushd "${1}"

  folders=$(find . -type d -maxdepth 1 -mindepth 1)
  files=$(find . -type f -maxdepth 1 -mindepth 1 -name "*.yaml" -not -name "kustomization.yaml")

  [[ -z "${files}" && -z "${folders}" ]] && popd && return

  [[ -f "kustomization.yaml" ]] && rm -f kustomization.yaml

  echo "${KUSTOMIZATION_TEMPLATE}" > kustomization.yaml


  for folder in $folders; do
    echo "  - ${folder#./}" >> kustomization.yaml
  done
  for file in $files; do
    echo "  - ${file#./}" >> kustomization.yaml
  done

  [[ -z "${folders}" ]] && popd && return

  for folder in ${folders}; do
    process_folder "${folder}"
  done

  popd
}

for base_folder in "${BASE_FOLDERS[@]}"; do
  process_folder "${base_folder}"
done

git checkout -- core/flux-system/kustomization.yaml
