#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

show_help() {
  cat <<EOF
Usage: $(basename "$0") <options>
    -h, --help                      Display help
    --source-file                   Original helm release
    --target-file                   New helm release
    --remove-common-labels          Remove common labels from manifests
EOF
}

main() {
  local source_file=
  local target_file=
  local remove_common_labels=
  parse_command_line "$@"
  check "helm"
  check "yq"
  entry
}

parse_command_line() {
  while :; do
    case "${1:-}" in
    -h | --help)
      show_help
      exit
      ;;
    --source-file)
      if [[ -n "${2:-}" ]]; then
        source_file="$2"
        shift
      else
        echo "ERROR: '--source-file' cannot be empty." >&2
        show_help
        exit 1
      fi
      ;;
    --target-file)
      if [[ -n "${2:-}" ]]; then
        target_file="$2"
        shift
      else
        echo "ERROR: '--target-file' cannot be empty." >&2
        show_help
        exit 1
      fi
      ;;
    --remove-common-labels)
      remove_common_labels=true
      ;;
    *)
      break
      ;;
    esac
    shift
  done

  if [[ -z "${source_file}" ]]; then
    echo "ERROR: '--source-file' is required." >&2
    show_help
    exit 1
  fi

  if [[ -f "${source_file}" && $(yq eval .kind "${source_file}" 2>/dev/null) != "HelmRelease" ]]; then
    echo "ERROR: '--source-file' is not a HelmRelease"
    show_help
    exit 1
  fi

  if [[ -z "${target_file}" ]]; then
    echo "ERROR: '--target-file' is required." >&2
    show_help
    exit 1
  fi

  if [[ $(yq eval .kind "${target_file}" 2>/dev/null) != "HelmRelease" ]]; then
    echo "ERROR: '--target-file' is not a HelmRelease"
    show_help
    exit 1
  fi

  if [[ -z "$remove_common_labels" ]]; then
    remove_common_labels=false
  fi
}

_resources() {
  local chart_name=${1}
  local chart_version=${2}
  local chart_registry_url=${3}
  local chart_values=${4}
  local resources=
  local chart_directory
  chart_directory=$(mktemp -d)

  # Keep each render isolated; never modify the caller's Helm repositories.
  if ! helm pull "${chart_name}" --repo "${chart_registry_url}" --destination "${chart_directory}" --version "${chart_version}" >&2; then
    rm -r "${chart_directory}"
    return 1
  fi
  if ! resources=$(echo "${chart_values}" | helm template "${render_release}" "${chart_directory}/${chart_name}-${chart_version}.tgz" --namespace "${render_namespace}" -f -); then
    rm -r "${chart_directory}"
    return 1
  fi
  rm -r "${chart_directory}"
  if [[ "${remove_common_labels}" == "true" ]]; then
    labels='.metadata.labels."helm.sh/chart"'
    labels+=',.metadata.labels.chart'
    labels+=',.metadata.labels."app.kubernetes.io/version"'
    labels+=',.spec.template.metadata.labels."helm.sh/chart"'
    labels+=',.spec.template.metadata.labels.chart'
    labels+=',.spec.template.metadata.labels."app.kubernetes.io/version"'
    echo "${resources}" | yq eval "del($labels)" -
  else
    echo "${resources}"
  fi
}

entry() {
  local comments=
  local work_directory
  local render_release render_namespace
  work_directory=$(mktemp -d)
  trap "rm -r -- '${work_directory}'" EXIT
  # valuesFrom and Flux substitutions need cluster secrets; do not imply parity.
  printf 'Path: `%s`\n\n' "${target_file}"
  printf '> Preview uses inline values only; valuesFrom, Flux substitutions and postRenderers are not applied. Generated chart values may produce noisy diffs.\n\n'
  if [[ $(yq '.spec.chart.spec.sourceRef.kind' "${target_file}") != HelmRepository ]]; then
    printf 'Preview unavailable: this release does not use a HelmRepository chart source. GitRepository and OCIRepository sources require a Flux-aware renderer.\n'
    return
  fi
  if [[ -f "${source_file}" && $(yq '.spec.chart.spec.sourceRef.kind' "${source_file}") != HelmRepository ]]; then
    printf 'Preview unavailable: the previous release did not use a HelmRepository chart source.\n'
    return
  fi

  if [[ -f "${source_file}" ]]; then
  source_chart_name=$(chart_name "${source_file}")
  source_chart_version=$(chart_version "${source_file}")
  source_chart_registry_url=$(chart_registry_url "${source_file}")
  source_chart_values=$(chart_values "${source_file}")
  render_release=$(yq '.spec.releaseName // .metadata.name' "${source_file}")
  render_namespace=$(yq '.spec.targetNamespace // .metadata.namespace // "default"' "${source_file}")
  source_resources=$(_resources "${source_chart_name}" "${source_chart_version}" "${source_chart_registry_url}" "${source_chart_values}") || exit 1
  else
    source_chart_name= source_chart_version= source_chart_registry_url= source_resources=
  fi
  echo "${source_resources}" >"${work_directory}/source_resources"

  target_chart_version=$(chart_version "${target_file}")
  target_chart_name=$(chart_name "${target_file}")
  target_chart_registry_url=$(chart_registry_url "${target_file}")
  target_chart_values=$(chart_values "${target_file}")
  render_release=$(yq '.spec.releaseName // .metadata.name' "${target_file}")
  render_namespace=$(yq '.spec.targetNamespace // .metadata.namespace // "default"' "${target_file}")
  target_resources=$(_resources "${target_chart_name}" "${target_chart_version}" "${target_chart_registry_url}" "${target_chart_values}") || exit 1
  echo "${target_resources}" >"${work_directory}/target_resources"

  # Diff the files and always return true
  local diff_status=0
  diff -u "${work_directory}/source_resources" "${work_directory}/target_resources" >"${work_directory}/diff" || diff_status=$?
  [[ "$diff_status" -le 1 ]] || exit "$diff_status"
  # Remove the filenames
  sed '1,2d' "${work_directory}/diff" >"${work_directory}/diff_body"

  # Store the comment in an array
  comments=()

  if [[ "${source_chart_name}" != "${target_chart_name}" ]]; then
    # shellcheck disable=SC2016
    comments+=("$(printf 'Chart: `%s` -> `%s`' "${source_chart_name}" "${target_chart_name}")")
  fi
  if [[ "${source_chart_version}" != "${target_chart_version}" ]]; then
    # shellcheck disable=SC2016
    comments+=("$(printf 'Version: `%s` -> `%s`' "${source_chart_version}" "${target_chart_version}")")
  fi
  if [[ "${source_chart_registry_url}" != "${target_chart_registry_url}" ]]; then
    # shellcheck disable=SC2016
    comments+=("$(printf 'Registry URL: `%s` -> `%s`' "${source_chart_registry_url}" "${target_chart_registry_url}")")
  fi
  comments+=("$(printf '\n\n')")
  if [[ -s "${work_directory}/diff_body" ]]; then
    # shellcheck disable=SC2016
    # Stay below GitHub's comment limit even for very large chart upgrades.
    comments+=("$(printf '```diff\n%s\n```' "$(head -c 45000 "${work_directory}/diff_body")")")
    if [[ $(wc -c <"${work_directory}/diff_body") -gt 45000 ]]; then
      comments+=("Diff truncated to 45,000 bytes for the PR comment.")
    fi
  else
    # shellcheck disable=SC2016
    comments+=("$(printf '```\nNo changes detected in rendered resources\n```')")
  fi

  # Join the array with a new line and print it
  printf "%s\n" "${comments[@]}"
}

chart_registry_url() {
  local helm_release=
  local chart_id=
  helm_release="${1}"
  if [[ $(yq '.spec.chart.spec.sourceRef.kind' "${helm_release}") != HelmRepository ]]; then
    echo "ERROR: ${helm_release}: only HelmRepository chart sources are supported by this inline-values preview." >&2
    return 1
  fi
  chart_id=$(yq eval .spec.chart.spec.sourceRef.name "${helm_release}" 2>/dev/null)
  local repository_root=.
  [[ "$helm_release" != default/* ]] || repository_root=default
  # Discover all HelmRepository
  find "${repository_root}/cluster/flux/repositories/helm" -name '*.yaml' -type f -print0 | while IFS= read -r -d '' file; do
    # Skip non HelmRepository
    [[ $(yq eval .kind "${file}" 2>/dev/null) != "HelmRepository" ]] && continue
    # Skip unrelated HelmRepository
    [[ "${chart_id}" != $(yq eval .metadata.name "${file}" 2>/dev/null) ]] && continue
    yq eval .spec.url "${file}"
    break
  done
}

chart_name() {
  local helm_release=
  helm_release="${1}"
  yq eval .spec.chart.spec.chart "${helm_release}" 2>/dev/null
}

chart_version() {
  local helm_release=
  helm_release="${1}"
  yq eval .spec.chart.spec.version "${helm_release}" 2>/dev/null
}

chart_values() {
  local helm_release=
  helm_release="${1}"
  yq eval '.spec.values // {}' "${helm_release}" 2>/dev/null
}

check() {
  command -v "${1}" >/dev/null 2>&1 || {
    echo >&2 "ERROR: ${1} is not installed or not found in \$PATH" >&2
    exit 1
  }
}

main "$@"
