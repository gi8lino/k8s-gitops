#!/usr/bin/env bash

set -o errexit

[[ ! "${PWD}" =~ "k8s-gitops/hack" ]] && echo "please cd to the 'hack' folder and run the script from there!" && exit 1

secrets=$(grep --files-with-matches --recursive --regexp "^kind: Secret$" --exclude="*.template" ..)
SECRET_WARN_MESSAGE="##################################################
# make sure to delete all secrets before saving! #
##################################################"

for secret in ${secrets}; do
  filepath=$(dirname "${secret}")
  filename=$(basename "${secret}")
  secret_template_name="${filepath}/${filename%.*}.template"

  [[ -f ${secret_template_name} ]] && echo "secret template '${secret_template_name}' already exists" && continue

  echo "creating secret template '${secret_template_name}'"

  grep --quiet --regexp "ENC.AES256" "${secret}" || sops --encrypt --in-place "${secret}" 2> /dev/null

  printf '%s\n' "${SECRET_WARN_MESSAGE}" "$(sops --decrypt "${secret}")" > "${secret_template_name}"

  vim "${secret_template_name}"
  tail -n +4 "${secret_template_name}" > "${secret_template_name}2"
  mv "${secret_template_name}2" "${secret_template_name}"
done
