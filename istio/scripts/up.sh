#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

chmod +x "${ROOT}/istio/scripts/"*.sh

"${ROOT}/istio/scripts/preload-istio-images.sh"
"${ROOT}/istio/scripts/install-istio-kind.sh"

"${ROOT}/istio/scripts/bootstrap-workloads.sh"
kubectl apply -f "${ROOT}/istio/k8s/services.yaml"

cd "${ROOT}"
docker compose up --build -d
sleep 6
"${ROOT}/istio/scripts/sync-workload-entries.sh"
sleep 2

curl -sf "http://localhost:3000/orders/istio-demo"
echo
