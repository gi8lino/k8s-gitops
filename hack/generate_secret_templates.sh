#!/usr/bin/env bash

set -o errexit

NOFORMAT='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'

ShowHelp() {
    printf "
Usage: generate_secret_template.sh [-f|--force]
                                   | [-h|--help]

Generates 'secret.template' files for SOPS-encrypted Kubernetes secrets.
Unencrypted secret will be automatically decrypted!

-f, --force         override existing templates
-h, --help          display this help and exit
\n"
    exit 0
}

while [ $# -gt 0 ]; do
    key="$1"
    case $key in
        -f|--force)
        FORCE=True
        shift
        ;;
        -h|--help)
        ShowHelp
        ;;
        *)  # unknown option
        printf "%s\n" \
           "${RED}[ERROR]${NOFORMAT} $(basename $BASH_SOURCE): invalid option -- '$1'" \
           "Try '$(basename $BASH_SOURCE) --help' for more information."
        exit 1
        ;;
    esac
done

secrets=$(grep \
              --files-with-matches \
              --recursive \
              --regexp "^kind: Secret$" \
              --exclude="*.template" *)

for secret in ${secrets}; do
  filepath=$(dirname "${secret}")
  filename=$(basename "${secret}")
  secret_template_name="${filepath}/${filename%.*}.template"

  [ "${FORCE}" = True ] && \
    rm -f ${secret_template_name}

  [[ -f ${secret_template_name} ]] && \
    printf "${ORANGE}[INFO ]${NOFORMAT} secret template '${secret_template_name}' already exists\n" && \
    continue

  # encrypt secret if necessary
  grep --quiet --regexp "ENC.AES256" "${secret}" || sops --encrypt --in-place "${secret}" 2> /dev/null

  printf "${GREEN}[INFO ]${NOFORMAT} creating secret template '${secret_template_name}'\n"
  printf '%s\n' > ${secret_template_name} "$(yq eval '.stringData[] = ""' <(sops --decrypt ${secret}))"

done
