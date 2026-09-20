#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

# Resolve container name: explicit env > docker compose service name > legacy default.
container_for_service() {
  local service="$1"
  local env_var="$2"
  local legacy_default="$3"

  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi

  local cid
  cid="$(docker compose ps -q "${service}" 2>/dev/null | head -1 || true)"
  if [[ -n "${cid}" ]]; then
    docker inspect -f '{{.Name}}' "${cid}" | sed 's/^\///'
    return 0
  fi

  if docker inspect "${legacy_default}" >/dev/null 2>&1; then
    echo "${legacy_default}"
    return 0
  fi

  echo "Could not find container for compose service '${service}'." >&2
  echo "Set ${env_var} to the exact name from 'docker compose ps'." >&2
  echo "" >&2
  docker compose ps >&2 || docker ps --format 'table {{.Names}}\t{{.Status}}' >&2
  exit 1
}

PAYMENT_C="$(container_for_service payment-service PAYMENT_CONTAINER s2s-service-mesh-payment-service-1)"
ORDER_C="$(container_for_service order-service ORDER_CONTAINER s2s-service-mesh-order-service-1)"
NOTIFICATION_C="$(container_for_service notification-service NOTIFICATION_CONTAINER s2s-service-mesh-notification-service-1)"

ip_for() {
  local name="$1"
  if ! docker inspect "${name}" >/dev/null 2>&1; then
    echo "No such object: ${name}" >&2
    echo "Running containers:" >&2
    docker compose ps >&2
    exit 1
  fi
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${name}"
}

echo "Using containers:"
echo "  payment:      ${PAYMENT_C}"
echo "  order:        ${ORDER_C}"
echo "  notification: ${NOTIFICATION_C}"

PAYMENT_IP="$(ip_for "${PAYMENT_C}")"
ORDER_IP="$(ip_for "${ORDER_C}")"
NOTIFICATION_IP="$(ip_for "${NOTIFICATION_C}")"

if [[ -z "${PAYMENT_IP}" || -z "${ORDER_IP}" || -z "${NOTIFICATION_IP}" ]]; then
  echo "Missing IP (is docker compose up?). payment=${PAYMENT_IP} order=${ORDER_IP} notification=${NOTIFICATION_IP}" >&2
  exit 1
fi

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: WorkloadEntry
metadata:
  name: payment-docker
  namespace: mesh-workloads
  labels:
    app: payment
spec:
  address: ${PAYMENT_IP}
  serviceAccount: payment
  ports:
    http: 4000
---
apiVersion: networking.istio.io/v1
kind: WorkloadEntry
metadata:
  name: order-docker
  namespace: mesh-workloads
  labels:
    app: order
spec:
  address: ${ORDER_IP}
  serviceAccount: order
  ports:
    http: 3000
---
apiVersion: networking.istio.io/v1
kind: WorkloadEntry
metadata:
  name: notification-docker
  namespace: mesh-workloads
  labels:
    app: notification
spec:
  address: ${NOTIFICATION_IP}
  serviceAccount: notification
  ports:
    http: 5000
EOF

echo "Registered WorkloadEntries:"
echo "  payment      ${PAYMENT_IP}:4000"
echo "  order        ${ORDER_IP}:3000"
echo "  notification ${NOTIFICATION_IP}:5000"
