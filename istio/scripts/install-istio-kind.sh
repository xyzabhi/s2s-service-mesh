#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ISTIO_TAG="${ISTIO_TAG:-1.31.0}"
ISTIO_HUB="${ISTIO_HUB:-docker.io/istio}"

"${ROOT}/istio/scripts/preload-istio-images.sh"

INSTALL_ARGS=(
  -y
  -f "${ROOT}/istio/istio-nodeport.yaml"
  --set "hub=${ISTIO_HUB}"
  --set "tag=${ISTIO_TAG}"
  --set values.global.imagePullPolicy=IfNotPresent
)

if ! kubectl get ns istio-system &>/dev/null; then
  echo "Installing Istio (minimal profile, istiod NodePort 31215)..."
  istioctl install "${INSTALL_ARGS[@]}"
else
  echo "istio-system exists; reconciling install..."
  istioctl install "${INSTALL_ARGS[@]}"
fi

# Ensure kubelet does not try registry pull when image is already on the Kind node.
if kubectl get deployment istiod -n istio-system &>/dev/null; then
  kubectl patch deployment istiod -n istio-system --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]' \
    >/dev/null 2>&1 || true
  kubectl rollout status deployment/istiod -n istio-system --timeout=60s >/dev/null 2>&1 || true
fi

"${ROOT}/istio/scripts/wait-istiod.sh"
echo "istiod ready. Check NodePort: kubectl get svc istiod -n istio-system"
