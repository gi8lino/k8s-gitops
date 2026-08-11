#!/usr/bin/env bash
# Generates Renovate app scope rules from Kubernetes workload labels.
set -euo pipefail

# Resolve repo root and output target.
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
search_roots=(
  "$repo_root/cluster/apps"
  "$repo_root/cluster/infra"
)
output_file="${1:-$repo_root/.github/renovate/appScopes.json5}"

for search_root in "${search_roots[@]}"; do
  if [[ ! -d "$search_root" ]]; then
    echo "workload root not found: $search_root" >&2
    exit 1
  fi
done

# extract_scope: prefer app.kubernetes.io/name, then derive HelmRelease scope.
extract_scope() {
  local file="$1"
  local value
  # Keep parsing minimal; YAML parsing is out of scope here.
  value=$(awk -F: '/app.kubernetes.io\/name:/ {print $2; exit}' "$file" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')
  if [[ -z "$value" && "$(basename "$file")" == "helmrelease.yaml" ]]; then
    case "$file" in
      "$repo_root"/cluster/apps/*)
        value=$(awk '/^metadata:/{metadata=1; next} metadata && /^  namespace:/{print $2; exit}' "$file")
        ;;
      *)
        value=$(awk '/^metadata:/{metadata=1; next} metadata && /^  name:/{print $2; exit}' "$file")
        ;;
    esac
  fi
  if [[ -n "$value" ]]; then
    echo "$value"
  fi
}

seen_rules=$'\n'
scopes=()
paths=()

# Collect unique (scope, path) pairs from workload manifests.
while IFS= read -r file; do
  label=$(extract_scope "$file" || true)
  if [[ -z "$label" ]]; then
    continue
  fi

  dir=$(dirname "$file")
  rel_dir="${dir#$repo_root/}"
  rule_key="${label}::${rel_dir}"
  case "$seen_rules" in
    *$'\n'"$rule_key"$'\n'*) continue ;;
  esac

  seen_rules="${seen_rules}${rule_key}"$'\n'
  scopes+=("$label")
  paths+=("$rel_dir")
done < <(
  find "${search_roots[@]}" -type f \
    \( -name deployment.yaml -o -name statefulset.yaml -o -name daemonset.yaml -o -name cronjob.yaml -o -name helmrelease.yaml \) \
    | sort
)

# Render Renovate rules in JSON5.
{
  echo '{'
  echo '  "$schema": "https://docs.renovatebot.com/renovate-schema.json",'
  echo '  "packageRules": ['

  total="${#scopes[@]}"
  for ((i = 0; i < total; i++)); do
    scope="${scopes[$i]}"
    path="${paths[$i]}"

    echo '    {'
    echo "      \"description\": \"App scope: ${scope}\","
    echo '      "matchDatasources": ["docker"],'
    echo "      \"matchPaths\": [\"${path}/**\"],"
    echo "      \"semanticCommitScope\": \"${scope}\""
    if (( i < total - 1 )); then
      echo '    },'
    else
      echo '    }'
    fi
  done

  echo
  echo '  ]'
  echo '}'
} > "$output_file"

echo "Wrote $output_file"
