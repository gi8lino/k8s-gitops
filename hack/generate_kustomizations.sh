#!/usr/bin/env bash

set -o errexit

KUSTOMIZATION_TEMPLATE="---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:"

NOFORMAT='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'

ShowHelp() {
    printf "
Usage: generate_kustomizations.sh [-i|--ignore-folders \"FOLDER, ...\"]
                                  | [-h|--help]
                                  FOLDER [FOLDER ...]

Iterates recursively over each FOLDER and generates or updates
resources in the corresponding 'kustomization.yaml' files.
If a 'kustomization.yaml' has the key 'patchesStrategicMerge', the corresponding
'kustomization.yaml' will not be updated.

positional arguments:
FOLDER [FOLDER ...]                      one or more directories to iterate over recursively

optional parameters:
-i, --ignore-folders \"[Folder] ...\"      folders which should be skipped
                                         list of strings, separatet by a comma (case sensitive!)
-f, --flux-system-folder                 skip updating flux-system kustomization.yaml
-h, --help                               display this help and exit
\n"
    exit 0
}

while [ $# -gt 0 ]; do
    key="${1}"
    case $key in
        -i|--ignore-folders)
        IFS=',' read -r -a IGNORE_FOLDERS <<< "${2}"
        unset IFS
        shift
        shift
        ;;
        -f|--flux-system-folder)
        FLUX_FOLDER="${2}"
        shift
        shift
        ;;
        -h|--help)
        ShowHelp
        ;;
        *)
        BASE_FOLDERS+=("${key}")
        shift
        ;;
    esac
done

function process_folder {
  local directory="${1}"

  [ ! -d "${directory}" ] && \
    printf "${RED}[ERROR     ]${NOFORMAT} folder '${directory}' not found!\n" && \
    return

  [[ "${directory})" == *"${FLUX_FOLDER}"* ]] && \
    printf "${ORANGE}[SKIPPING  ]${NOFORMAT} ${directory}\n" && \
    return

  printf "${GREEN}[PROCESSING]${NOFORMAT} ${directory}\n"

  readarray -d '' folders < <(find "${directory}" \
                                    -type d \
                                    -maxdepth 1 \
                                    -mindepth 1 \
                                    -execdir printf '%s\n' {} + | sort)

  for folder in ${folders[@]}; do
    for ignore_folder in ${IGNORE_FOLDERS[@]}; do
      [[ "${directory}/${folder}" =~ "${ignore_folder}" ]] && \
        printf "${ORANGE}[SKIPPING  ]${NOFORMAT} ${directory}/${folder}\n" && \
        folders=( "${folders[@]/"${folder}"}" )  # remove skipped folder from list of folders
    done
  done

  readarray -d '' files < <(find "${directory}" \
                                  -type f \
                                  -maxdepth 1 \
                                  -mindepth 1 \
                                  \( \
                                    -name "*.yaml" \
                                    -o -name ".kustomizationignore" \
                                  \) \
                                  -not -name "kustomization.yaml" \
                                  -execdir printf '%s\n' {} + | sort)

  [[ -f "${directory}/kustomization.yaml" ]] && \
    [[ $(yq '. | has("patchesStrategicMerge")' "${directory}/kustomization.yaml") == true  ]] && \
      printf "${ORANGE}[SKIPPING  ]${NOFORMAT} ${directory} because 'kustomization.yaml' has 'patchesStrategicMerge'\n" && \
      return

  [[ -z "${files}" && -z "${folders}" ]] && \
    return

  [[ ! -f "${directory}/kustomization.yaml" ]] && \
    echo "${KUSTOMIZATION_TEMPLATE}" > "${directory}/kustomization.yaml"

  resources="${folders} ${files}"  # merge arrays
  resources=$(printf '"%s", ' ${resources[@]})  # add quotes to values and convert array to a string, separated by comma

  yq eval \
      --inplace \
      ".resources = [ ${resources%,*} ]"  `# remove ending comma` \
      "${directory}/kustomization.yaml"

  [[ -z "${folders}" ]] && \
    return

  for folder in ${folders}; do
    process_folder "${directory}/${folder}"
  done
}

[ -z "${BASE_FOLDERS}" ] && \
  printf "${RED}[ERROR     ]${NOFORMAT} no base folder given!\n" && \
  exit 1

for base_folder in "${BASE_FOLDERS[@]}"; do
  process_folder "$(pwd)/${base_folder}"
done

printf "${GREEN}[INFO      ]${NOFORMAT} finished!\n"
