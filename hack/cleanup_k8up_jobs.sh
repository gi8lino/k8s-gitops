#!/usr/bin/env bash

set -o errexit

NOFORMAT='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'

ShowHelp() {
    printf "
Usage: cleanup_k8up_jobs.sh [-A|--all-namespaces]
                            [-h|--help]

Searches for pods in current namespace with status 'Terminating' and label
'k8upjob', delete the related job and remove the finalizer of the pod so
the pod will be deleted.

-A, --all-namespaces   search in all namespaces for pod with status 'Terminating'
-h, --help             display this help and exit
\n"
    exit 0
}

while [ $# -gt 0 ]; do
    key="${1}"
    case $key in
        -A|--all-namespaces)
        ALLNAMESPACES="all-namespaces"
        shift
        ;;
        -h|--help)
        ShowHelp
        ;;
        *)  # unknown option
        printf "%s\n" \
          "$(basename $BASH_SOURCE): invalid option -- '$1'" \
          "Try '$(basename $BASH_SOURCE) --help' for more information."
        exit 1
        ;;
    esac
done

[ -n "${ALLNAMESPACES}" ] && \
  readarray -d '' namespaces < <(kubectl get ns -ojsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

[ -z "${namespaces}" ] && \
  readarray -d '' namespaces < <(kubectl config view --minify --output 'jsonpath={..namespace}')

for namespace in ${namespaces[@]}; do
  readarray -d '' pods < <(kubectl get pods --ignore-not-found --no-headers --namespace ${namespace} | awk '$3=="Terminating" {print $1}')

  [ -z "${pods[@]}" ] && \
    continue

  for pod in ${pods[*]}; do
    job_name=$(kubectl get pod "${pod}" --namespace "${namespace}" -ojsonpath='{.metadata.labels.job-name}')

    [ -z "${job_name}" ] && \
      continue

    printf "${GREEN}[INFO      ]${NOFORMAT} %s\n" "$(kubectl delete job --namespace "${namespace}" ${job_name})"
    printf "${GREEN}[INFO      ]${NOFORMAT} %s\n" "$(kubectl patch pod ${pod} --namespace "${namespace}" --patch='{"metadata":{"finalizers":null}}')"
  done
done
