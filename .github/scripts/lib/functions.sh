#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s lastpipe

check() {
  command -v "${1}" >/dev/null 2>&1 || {
    echo >&2 "ERROR: ${1} is not installed or not found in \$PATH" >&2
    exit 1
  }
}
