#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
monitoring_test_dir="$(mktemp -d)"
trap 'rm -rf "$monitoring_test_dir"' EXIT
promtool_bin="${PROMTOOL:-promtool}"

# Promtool consumes rule groups, not Kubernetes PrometheusRule objects.
yq '.spec' "$repo_root/cluster/infra/observability/kube-prometheus-stack/backup-prometheusrule.yaml" > "$monitoring_test_dir/backup.rules.yaml"
cp "$repo_root/hack/tests/monitoring/backup.test.yaml" "$monitoring_test_dir/"
"$promtool_bin" check rules "$monitoring_test_dir/backup.rules.yaml"
"$promtool_bin" test rules "$monitoring_test_dir/backup.test.yaml"
