#!/usr/bin/env bash

set -o errexit

NOFORMAT='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'

ShowHelp() {
    printf "
Usage: cleanup_k8up_jobs.sh [-h|--help]

Searches for pods in the current namespace with status 'Terminating' and label
'job-name', delete the related job and remove the finalizer of the pod so
the pod will be deleted.

-h, --help          display this help and exit
\n"
    exit 0
}

while [ $# -gt 0 ]; do
    key="${1}"
    case $key in
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

readarray -d '' pods < <(kubectl get pods | awk '$3=="Terminating" {print $1}')

for pod in ${pods[@]}; do
  job_name=$(kubectl get pod "${pod}" -ojsonpath='{.metadata.labels.job-name}')

  [ -z "${job_name}" ] && \
    printf "${ORANGE}[SKIPPING  ]${NOFORMAT} pod '${pod}' seems not be created from cronjob\n" && \
    continue

  printf "${GREEN}[INFO      ]${NOFORMAT} %s\n" "$(kubectl delete job ${job_name})"
  printf "${GREEN}[INFO      ]${NOFORMAT} %s\n" "$(kubectl patch pod ${pod} --patch='{"metadata":{"finalizers":null}}')"
done
