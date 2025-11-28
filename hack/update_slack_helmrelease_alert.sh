#!/usr/bin/env bash
set -euo pipefail

# Print usage instructions.
usage() {
  cat <<'EOF'
Usage: update_slack_helmrelease_alert.sh --alert-file ALERT_FILE [PATH ...]

Finds HelmRelease manifests under the given paths (defaults to ./cluster),
collects their namespaces, and updates the HelmRelease Alert eventSources
in the provided ALERT_FILE.
EOF
}

# Parse command line arguments.
if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

# Check for required dependencies.
if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required to parse and update HelmRelease manifests" >&2
  exit 1
fi

alert_file=""
search_paths=()

# Parse options; directories remain positional after options.
while [[ $# -gt 0 ]]; do
  case "$1" in
  -a | --alert-file)
    alert_file="${2:-}"
    if [[ -z "${alert_file}" ]]; then
      echo "Missing value for --alert-file" >&2
      exit 1
    fi
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    # End of options; anything after this is a search path.
    shift
    break
    ;;
  -*)
    printf "%s\n" "Invalid option: $1" >&2
    usage
    exit 1
    ;;
  *)
    break
    ;;
  esac
done

search_paths+=("$@")

if [[ -z "${alert_file}" ]]; then
  echo "Alert file path is required." >&2
  usage
  exit 1
fi

if [[ ! -f "${alert_file}" ]]; then
  echo "Alert file not found: ${alert_file}" >&2
  exit 1
fi

# Default search path if none provided.
if [[ ${#search_paths[@]} -eq 0 ]]; then
  search_paths=("cluster")
fi

for path in "${search_paths[@]}"; do
  if [[ ! -d "${path}" ]]; then
    echo "Path does not exist or is not a directory: ${path}" >&2
    exit 1
  fi
done

# Gather HelmRelease manifest paths.
mapfile -t hr_files < <(find "${search_paths[@]}" -type f \( -iname '*helmrelease.yaml' -o -iname '*helmrelease.yml' \) 2>/dev/null)
if [[ ${#hr_files[@]} == 0 ]]; then
  echo "No HelmRelease manifests found under: ${search_paths[*]}" >&2
  exit 1
fi

# Collect namespaces uniquely.
declare -A namespaces=()
for file in "${hr_files[@]}"; do
  while IFS= read -r ns; do
    [[ -z "${ns}" || "${ns}" == "null" ]] && continue
    namespaces["${ns}"]=1
  done < <(yq -r 'select(.kind == "HelmRelease") | .metadata.namespace // ""' "${file}")
done

if [[ ${#namespaces[@]} == 0 ]]; then
  echo "No HelmRelease namespaces found in manifests under: ${search_paths[*]}" >&2
  exit 1
fi

# Sort namespaces for deterministic output and build an inline yq expression.
mapfile -t sorted_namespaces < <(printf '%s\n' "${!namespaces[@]}" | sort)
event_source_items=()
for ns in "${sorted_namespaces[@]}"; do
  # Build each eventSource item as a quoted yq object literal.
  event_source_items+=("{\"kind\": \"HelmRelease\", \"namespace\": \"${ns}\", \"name\": \"*\"}")
done
# Join items into a single array literal for yq.
event_sources_array="$(
  IFS=','
  printf '%s' "${event_source_items[*]}"
)"

# Update only the helmreleases Alert document using the inline array literal.
yq eval --inplace "select(.metadata.name == \"helmreleases\") |= (.spec.eventSources = [${event_sources_array}])" "${alert_file}"

echo "Updated HelmRelease alert namespaces in ${alert_file}"
