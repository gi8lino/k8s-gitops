#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: list_helmrelease_namespaces.sh [PATH ...]

Prints the unique namespaces used by HelmRelease manifests under the given
paths (defaults to ./cluster).
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required to parse HelmRelease manifests" >&2
  exit 1
fi

search_paths=("$@")
if [[ ${#search_paths[@]} -eq 0 ]]; then
  search_paths=("cluster")
fi

for path in "${search_paths[@]}"; do
  if [[ ! -d "${path}" ]]; then
    echo "Path does not exist or is not a directory: ${path}" >&2
    exit 1
  fi
done

mapfile -t hr_files < <(find "${search_paths[@]}" -type f \( -iname '*helmrelease.yaml' -o -iname '*helmrelease.yml' \) 2>/dev/null)

if [[ ${#hr_files[@]} -eq 0 ]]; then
  echo "No HelmRelease manifests found under: ${search_paths[*]}" >&2
  exit 1
fi

declare -A namespaces=()

for file in "${hr_files[@]}"; do
  while IFS= read -r ns; do
    [[ -z "${ns}" || "${ns}" == "null" ]] && continue
    namespaces["${ns}"]=1
  done < <(yq -r 'select(.kind == "HelmRelease") | .metadata.namespace // ""' "${file}")
done

printf "%s\n" "${!namespaces[@]}" | sort
