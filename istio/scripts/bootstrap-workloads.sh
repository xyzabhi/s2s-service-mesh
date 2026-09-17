#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=istio/scripts/patch-mesh.sh
source "${ROOT}/istio/scripts/patch-mesh.sh"

ISTIODiscovery="${ISTIOD_DISCOVERY_ADDR:-istiod.istio-system.svc:31215}"

echo "Applying Kubernetes workload definitions..."
kubectl apply -f "${ROOT}/istio/k8s/namespace.yaml"
kubectl apply -f "${ROOT}/istio/k8s/serviceaccounts.yaml"
kubectl apply -f "${ROOT}/istio/k8s/services.yaml"
kubectl apply -f "${ROOT}/istio/k8s/envoyfilter-response-headers.yaml"
kubectl apply -f "${ROOT}/istio/workloads/order-workloadgroup.yaml"
kubectl apply -f "${ROOT}/istio/workloads/payment-workloadgroup.yaml"
kubectl apply -f "${ROOT}/istio/workloads/notification-workloadgroup.yaml"

configure_workload() {
  local wg="$1"
  local out="$2"
  mkdir -p "${out}"
  istioctl experimental workload entry configure \
    -f "${wg}" \
    --autoregister \
    --namespace mesh-workloads \
    -o "${out}"

  local mesh="${out}/mesh"
  if [[ -f "${out}/mesh.yaml" ]]; then
    patch_mesh_file "${out}/mesh.yaml"
  fi
  if [[ -f "${mesh}" ]]; then
    patch_mesh_file "${mesh}"
  fi
  if [[ ! -f "${mesh}" && ! -f "${out}/mesh.yaml" ]]; then
    echo "missing mesh config in ${out}" >&2
    exit 1
  fi

  local network_id=""
  case "$(basename "${out}")" in
    order-config) network_id="network-order" ;;
    payment-config) network_id="network-payment" ;;
    notification-config) network_id="network-notification" ;;
  esac

  if [[ -n "${network_id}" ]]; then
    patch_cluster_env "${out}/cluster.env" "${network_id}"
    if [[ -f "${out}/mesh.yaml" ]]; then
      patch_mesh_network "${out}/mesh.yaml" "${network_id}"
    fi
    if [[ -f "${mesh}" ]]; then
      patch_mesh_network "${mesh}" "${network_id}"
    fi
  fi
}

configure_workload "${ROOT}/istio/workloads/order-workloadgroup.yaml" "${ROOT}/istio/workloads/order-config"
configure_workload "${ROOT}/istio/workloads/payment-workloadgroup.yaml" "${ROOT}/istio/workloads/payment-config"
configure_workload "${ROOT}/istio/workloads/notification-workloadgroup.yaml" "${ROOT}/istio/workloads/notification-config"

echo "Bootstrap complete."
echo "  order:        ${ROOT}/istio/workloads/order-config"
echo "  payment:      ${ROOT}/istio/workloads/payment-config"
echo "  notification: ${ROOT}/istio/workloads/notification-config"
echo "Start mesh: docker compose up --build"
