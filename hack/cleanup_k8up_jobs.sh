#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: cleanup_k8up_jobs.sh [-A|--all-namespaces] [-h|--help]

Delete Jobs owning terminating pods labeled 'k8upjob=true', then remove
those pods' finalizers. Defaults to the current kubectl namespace.

-A, --all-namespaces   search in all namespaces
-h, --help             display this help and exit
HELP
}

namespace_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -A|--all-namespaces)
      namespace_args=(--all-namespaces)
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '%s\n' "$(basename "$0"): invalid option -- '$1'" >&2
      exit 1
      ;;
  esac
  shift
done

# Let kubectl resolve the current namespace (including its default fallback).
# Capture the result directly so API errors stop the script before any deletion.
# Only Job owner references qualify; a job-name label alone is not ownership.
pods=$(kubectl get pods ${namespace_args[@]+"${namespace_args[@]}"} \
  --selector=k8upjob=true \
  -o 'jsonpath={range .items[?(@.metadata.deletionTimestamp)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.metadata.ownerReferences[?(@.kind=="Job")].name}{"\n"}{end}')

while IFS=$'\t' read -r namespace pod job_name; do
  [[ -n "$namespace" && -n "$pod" && -n "$job_name" ]] || continue

  # Do not wait for Job deletion: its pods may need their finalizers removed.
  kubectl delete job "$job_name" --namespace "$namespace" --wait=false --ignore-not-found
  kubectl patch pod "$pod" --namespace "$namespace" \
    --type=merge --patch='{"metadata":{"finalizers":null}}'
done <<< "$pods"
