#!/usr/bin/env bash
set -euo pipefail

MINIO_NS="${MINIO_NS:-minio}"
VALUES_SECRET="${VALUES_SECRET:-minio-helm-values}"
VALUES_KEY="${VALUES_KEY:-values.yaml}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio:9000}"
MC_IMAGE="${MC_IMAGE:-quay.io/minio/mc:latest}"

# Safety guard. Run once without APPLY=1 first.
APPLY="${APPLY:-0}"

# Keep policies by default so reruns work. Set to 1 for a fully temporary run.
CLEANUP_NETWORK_POLICIES="${CLEANUP_NETWORK_POLICIES:-0}"

SYNC_APP_LABEL="${SYNC_APP_LABEL:-minio-user-sync}"
POD="minio-user-sync-$(date +%s)"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

cleanup() {
  kubectl -n "$MINIO_NS" delete pod "$POD" --ignore-not-found=true >/dev/null 2>&1 || true

  if [[ "$CLEANUP_NETWORK_POLICIES" == "1" ]]; then
    kubectl -n "$MINIO_NS" delete ciliumnetworkpolicy minio-user-sync --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl -n "$MINIO_NS" delete ciliumnetworkpolicy minio-ingress-user-sync --ignore-not-found=true >/dev/null 2>&1 || true
  fi

  rm -rf "${TMPDIR:-}"
}
trap cleanup EXIT INT TERM

need kubectl
need yq
need base64

TMPDIR="$(mktemp -d)"
VALUES_FILE="$TMPDIR/values.yaml"

echo "Applying temporary Cilium network policies..."

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: minio-user-sync
  namespace: ${MINIO_NS}
spec:
  description: Allow temporary MinIO user sync pod to reach DNS and MinIO
  endpointSelector:
    matchLabels:
      app: ${SYNC_APP_LABEL}
  egress:
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/instance: minio
            app.kubernetes.io/name: minio
            io.kubernetes.pod.namespace: ${MINIO_NS}
      toPorts:
        - ports:
            - port: "9000"
              protocol: TCP
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: minio-ingress-user-sync
  namespace: ${MINIO_NS}
spec:
  description: Allow temporary MinIO user sync pod to reach MinIO
  endpointSelector:
    matchLabels:
      app.kubernetes.io/instance: minio
      app.kubernetes.io/name: minio
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: ${SYNC_APP_LABEL}
            io.kubernetes.pod.namespace: ${MINIO_NS}
      toPorts:
        - ports:
            - port: "9000"
              protocol: TCP
EOF

echo "Fetching ${MINIO_NS}/${VALUES_SECRET}:${VALUES_KEY}..."

kubectl -n "$MINIO_NS" get secret "$VALUES_SECRET" \
  -o "jsonpath={.data.${VALUES_KEY//./\\.}}" | base64 -d >"$VALUES_FILE"

ROOT_USER="$(yq -r '.rootUser // ""' "$VALUES_FILE")"
ROOT_PASSWORD="$(yq -r '.rootPassword // ""' "$VALUES_FILE")"
USER_COUNT="$(yq -r '.users | length' "$VALUES_FILE")"

if [[ -z "$ROOT_USER" || "$ROOT_USER" == "null" ]]; then
  echo "rootUser is empty in ${MINIO_NS}/${VALUES_SECRET}" >&2
  exit 1
fi

if [[ -z "$ROOT_PASSWORD" || "$ROOT_PASSWORD" == "null" ]]; then
  echo "rootPassword is empty in ${MINIO_NS}/${VALUES_SECRET}" >&2
  exit 1
fi

if [[ "$USER_COUNT" == "0" || "$USER_COUNT" == "null" ]]; then
  echo "No users found in ${MINIO_NS}/${VALUES_SECRET}" >&2
  exit 1
fi

echo "Starting temporary mc pod: $POD"

kubectl -n "$MINIO_NS" run "$POD" \
  --restart=Never \
  --image="$MC_IMAGE" \
  --labels="app=${SYNC_APP_LABEL}" \
  --command -- sleep 3600 >/dev/null

kubectl -n "$MINIO_NS" wait --for=condition=Ready "pod/$POD" --timeout=60s >/dev/null

kubectl -n "$MINIO_NS" exec -i "$POD" -- sh -ceu 'umask 077; cat > /tmp/root.env' <<EOF
MINIO_ENDPOINT_B64=$(b64 "$MINIO_ENDPOINT")
ROOT_USER_B64=$(b64 "$ROOT_USER")
ROOT_PASSWORD_B64=$(b64 "$ROOT_PASSWORD")
EOF

echo "Validating MinIO admin login..."

kubectl -n "$MINIO_NS" exec "$POD" -- sh -ceu '
. /tmp/root.env

MINIO_ENDPOINT="$(printf "%s" "$MINIO_ENDPOINT_B64" | base64 -d)"
ROOT_USER="$(printf "%s" "$ROOT_USER_B64" | base64 -d)"
ROOT_PASSWORD="$(printf "%s" "$ROOT_PASSWORD_B64" | base64 -d)"

mc alias set myminio "$MINIO_ENDPOINT" "$ROOT_USER" "$ROOT_PASSWORD" >/dev/null
mc admin info myminio >/dev/null
'

echo
echo "Users found in values.yaml: $USER_COUNT"
echo "APPLY=$APPLY"
echo

for i in $(seq 0 $((USER_COUNT - 1))); do
  ACCESS_KEY="$(yq -r ".users[$i].accessKey // \"\"" "$VALUES_FILE")"
  SECRET_KEY="$(yq -r ".users[$i].secretKey // \"\"" "$VALUES_FILE")"
  POLICY="$(yq -r ".users[$i].policy // \"\"" "$VALUES_FILE")"

  if [[ -z "$ACCESS_KEY" || "$ACCESS_KEY" == "null" ]]; then
    echo "Skipping users[$i]: empty accessKey"
    continue
  fi

  if [[ -z "$SECRET_KEY" || "$SECRET_KEY" == "null" ]]; then
    echo "ERROR: users[$i] '$ACCESS_KEY' has empty secretKey" >&2
    exit 1
  fi

  if [[ -z "$POLICY" || "$POLICY" == "null" ]]; then
    echo "ERROR: users[$i] '$ACCESS_KEY' has empty policy" >&2
    exit 1
  fi

  echo "Reconciling MinIO user '$ACCESS_KEY' with policy '$POLICY'..."

  kubectl -n "$MINIO_NS" exec -i "$POD" -- sh -ceu 'umask 077; cat > /tmp/user.env' <<EOF
ACCESS_KEY_B64=$(b64 "$ACCESS_KEY")
SECRET_KEY_B64=$(b64 "$SECRET_KEY")
POLICY_B64=$(b64 "$POLICY")
APPLY_B64=$(b64 "$APPLY")
EOF

  kubectl -n "$MINIO_NS" exec "$POD" -- sh -ceu '
. /tmp/root.env
. /tmp/user.env

MINIO_ENDPOINT="$(printf "%s" "$MINIO_ENDPOINT_B64" | base64 -d)"
ROOT_USER="$(printf "%s" "$ROOT_USER_B64" | base64 -d)"
ROOT_PASSWORD="$(printf "%s" "$ROOT_PASSWORD_B64" | base64 -d)"
ACCESS_KEY="$(printf "%s" "$ACCESS_KEY_B64" | base64 -d)"
SECRET_KEY="$(printf "%s" "$SECRET_KEY_B64" | base64 -d)"
POLICY="$(printf "%s" "$POLICY_B64" | base64 -d)"
APPLY="$(printf "%s" "$APPLY_B64" | base64 -d)"

mc alias set myminio "$MINIO_ENDPOINT" "$ROOT_USER" "$ROOT_PASSWORD" >/dev/null

if ! mc admin policy info myminio "$POLICY" >/dev/null 2>&1; then
  echo "  ERROR: policy does not exist in MinIO: $POLICY" >&2
  exit 1
fi

if [ "$APPLY" != "1" ]; then
  if mc admin user info myminio "$ACCESS_KEY" >/dev/null 2>&1; then
    echo "  DRY RUN: user exists; would remove and recreate: $ACCESS_KEY"
  else
    echo "  DRY RUN: user missing; would create: $ACCESS_KEY"
  fi
  echo "  DRY RUN: would attach policy: $POLICY"
  exit 0
fi

if mc admin user info myminio "$ACCESS_KEY" >/dev/null 2>&1; then
  echo "  user exists; removing before recreate"
  mc admin user disable myminio "$ACCESS_KEY" >/dev/null 2>&1 || true
  mc admin user rm myminio "$ACCESS_KEY" >/dev/null
fi

mc admin user add myminio "$ACCESS_KEY" "$SECRET_KEY" >/dev/null
mc admin policy attach myminio "$POLICY" --user "$ACCESS_KEY" >/dev/null
mc admin user info myminio "$ACCESS_KEY" >/dev/null

# Validate that the new credentials authenticate. Do not list buckets here,
# because some users only have access to specific bucket patterns.
mc alias set verify "$MINIO_ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY" >/dev/null

echo "  OK"
'
done

echo
if [[ "$APPLY" != "1" ]]; then
  echo "Dry run complete. Re-run with APPLY=1 to modify MinIO users."
else
  echo "Done. MinIO users now match ${MINIO_NS}/${VALUES_SECRET}:${VALUES_KEY}."
fi
