#!/usr/bin/env bash
set -euo pipefail

PAYMENT_C="${PAYMENT_CONTAINER:-s2s-service-mesh-payment-service-1}"
ORDER_C="${ORDER_CONTAINER:-s2s-service-mesh-order-service-1}"
NOTIFICATION_C="${NOTIFICATION_CONTAINER:-s2s-service-mesh-notification-service-1}"

ip_for() {
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1"
}

PAYMENT_IP="$(ip_for "${PAYMENT_C}")"
ORDER_IP="$(ip_for "${ORDER_C}")"
NOTIFICATION_IP="$(ip_for "${NOTIFICATION_C}")"

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
