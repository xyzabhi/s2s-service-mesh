#!/usr/bin/env bash
set -euo pipefail

PAYMENT_C="${PAYMENT_CONTAINER:-s2s-service-mesh-payment-service-1}"
ORDER_C="${ORDER_CONTAINER:-s2s-service-mesh-order-service-1}"
NOTIFICATION_C="${NOTIFICATION_CONTAINER:-s2s-service-mesh-notification-service-1}"

PAYMENT_NET="${PAYMENT_NETWORK:-s2s-payment-network}"
ORDER_NET="${ORDER_NETWORK:-s2s-order-network}"
NOTIFICATION_NET="${NOTIFICATION_NETWORK:-s2s-notification-network}"

ip_on_network() {
  local container="$1"
  local network="$2"
  docker inspect -f "{{range \$k, \$v := .NetworkSettings.Networks}}{{if eq \$k \"${network}\"}}{{\$v.IPAddress}}{{end}}{{end}}" "${container}"
}

PAYMENT_IP="$(ip_on_network "${PAYMENT_C}" "${PAYMENT_NET}")"
ORDER_IP="$(ip_on_network "${ORDER_C}" "${ORDER_NET}")"
NOTIFICATION_IP="$(ip_on_network "${NOTIFICATION_C}" "${NOTIFICATION_NET}")"

if [[ -z "${PAYMENT_IP}" || -z "${ORDER_IP}" || -z "${NOTIFICATION_IP}" ]]; then
  echo "Start compose first: docker compose up -d" >&2
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
  network: network-payment
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
  network: network-order
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
  network: network-notification
  serviceAccount: notification
  ports:
    http: 5000
EOF

echo "Registered WorkloadEntries:"
echo "  payment      ${PAYMENT_IP}@network-payment:4000"
echo "  order        ${ORDER_IP}@network-order:3000"
echo "  notification ${NOTIFICATION_IP}@network-notification:5000"
