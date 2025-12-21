#!/usr/bin/env bash
# Generates Renovate app scope rules from Kubernetes workload labels.
set -euo pipefail

# Resolve repo root and output target.
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
apps_root="$repo_root/cluster/apps"
output_file="${1:-$repo_root/.github/renovate/appScopes.json5}"

if [[ ! -d "$apps_root" ]]; then
  echo "apps root not found: $apps_root" >&2
  exit 1
fi

# extract_label: read app.kubernetes.io/name from a manifest file (first match).
extract_label() {
  local file="$1"
  local value
  # Keep parsing minimal; YAML parsing is out of scope here.
  value=$(awk -F: '/app.kubernetes.io\/name:/ {print $2; exit}' "$file" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')
  if [[ -n "$value" ]]; then
    echo "$value"
  fi
}

declare -A seen_rules
scopes=()
paths=()

# Collect unique (scope, path) pairs from workload manifests.
while IFS= read -r file; do
  label=$(extract_label "$file" || true)
  if [[ -z "$label" ]]; then
    continue
  fi

  dir=$(dirname "$file")
  rel_dir="${dir#$repo_root/}"
  rule_key="${label}::${rel_dir}"
  if [[ -n "${seen_rules[$rule_key]:-}" ]]; then
    continue
  fi

  seen_rules["$rule_key"]=1
  scopes+=("$label")
  paths+=("$rel_dir")
done < <(find "$apps_root" -type f \( -name deployment.yaml -o -name statefulset.yaml -o -name daemonset.yaml \) | sort)

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
