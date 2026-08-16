#!/usr/bin/with-contenv bash

set -euo pipefail

app_root=${SABNZBD_APP_ROOT:-/app/sabnzbd}
fragment=${SABNZBD_THEME_FIX_FRAGMENT:-/opt/sabnzbd/theme-fix.html}
marker=sabnzbd-5-1-theme-fix
templates=(
  "$app_root/interfaces/Glitter/templates/main.tmpl"
  "$app_root/interfaces/Config/templates/_inc_header_uc.tmpl"
)

if [ ! -f "$fragment" ]; then
  echo "SABnzbd theme fix fragment not found: $fragment" >&2
  exit 1
fi

for template in "${templates[@]}"; do
  if [ ! -f "$template" ]; then
    echo "SABnzbd template not found: $template" >&2
    exit 1
  fi

  if grep -q "$marker" "$template"; then
    echo "SABnzbd theme fix already present in $template"
    continue
  fi

  head_line=$(grep -n -m1 '</head>' "$template" | cut -d: -f1)
  if [ -z "$head_line" ]; then
    echo "Unable to find </head> in $template" >&2
    exit 1
  fi

  temporary_file=$(mktemp)
  {
    head -n "$((head_line - 1))" "$template"
    cat "$fragment"
    tail -n "+$head_line" "$template"
  } > "$temporary_file"

  cat "$temporary_file" > "$template"
  rm -f "$temporary_file"
  echo "Injected SABnzbd theme fix into $template"
done
