#!/usr/bin/env bash

set -o errexit

[[ "${PWD}" =~ "k8s-gitops/hack" ]] && echo "please cd to the root folder and run the script from there!" && exit 1

KUSTOMIZATION_TEMPLATE="---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:"

BASE_FOLDERS=("apps" "base" "core" "crds" "infra")
IGNORE_FOLDERS=(".img" "dashboards")

function process_folder {
  pushd "${1}"

  readarray -d '' folders < <(find . -type d -maxdepth 1 -mindepth 1 $(printf "! -name %s " ${IGNORE_FOLDERS[@]}) -execdir printf '%s\n' {} + )
  readarray -d '' files < <(find . -type f -maxdepth 1 -mindepth 1 -name "*.yaml" -not -name "kustomization.yaml" -execdir printf '%s\n' {} + )

  [[ -z "${files}" && -z "${folders}" ]] && popd && return

  [[ ! -f "kustomization.yaml" ]] && \
    echo "${KUSTOMIZATION_TEMPLATE}" > kustomization.yaml

  resources="${folders} ${files}"
  resources=$(printf '"%s", ' ${resources[@]})

  yq eval --inplace ".resources = [ ${resources%,*} ]" kustomization.yaml

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
