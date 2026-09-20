#!/usr/bin/env bash
# One-shot setup tuned for corporate laptops (preload images, minimal Istio, no in-cluster pulls).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

chmod +x "${ROOT}/istio/scripts/"*.sh

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need docker
need kubectl
need kind
need istioctl
need curl

if ! kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER:-kind}"; then
  echo "Creating Kind cluster (kind-config.yaml maps host port 31215 for istiod)..."
  kind create cluster --config "${ROOT}/kind-config.yaml"
fi

"${ROOT}/istio/scripts/preload-istio-images.sh"
"${ROOT}/istio/scripts/install-istio-kind.sh"
"${ROOT}/istio/scripts/bootstrap-workloads.sh"

docker compose up --build -d
sleep 8
"${ROOT}/istio/scripts/sync-workload-entries.sh"
sleep 2

echo "Smoke test:"
curl -sf "http://localhost:3000/orders/istio-demo"
echo
echo "Setup complete."
