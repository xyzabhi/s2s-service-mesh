#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! kubectl get ns istio-system &>/dev/null; then
  echo "Installing Istio with istiod NodePort 31215..."
  istioctl install -y -f "${ROOT}/istio/istio-nodeport.yaml"
else
  echo "istio-system already exists; ensuring NodePort install..."
  istioctl install -y -f "${ROOT}/istio/istio-nodeport.yaml"
fi

kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=120s
echo "istiod ready. NodePort 15012 -> check: kubectl get svc istiod -n istio-system"
