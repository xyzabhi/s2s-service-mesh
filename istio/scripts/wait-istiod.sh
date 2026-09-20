#!/usr/bin/env bash
set -euo pipefail

TIMEOUT="${ISTIOD_WAIT_TIMEOUT:-300s}"

echo "Waiting for istiod (timeout ${TIMEOUT})..."
if kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout="${TIMEOUT}"; then
  kubectl get pods -n istio-system -l app=istiod
  exit 0
fi

echo "istiod did not become ready. Diagnostics:" >&2
kubectl get pods -n istio-system -o wide >&2
kubectl describe pod -n istio-system -l app=istiod | tail -50 >&2

if kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null | grep -q ImagePull; then
  cat >&2 <<'EOF'

ImagePullBackOff: Kind must use images on the host, not pull from the internet.

  ./istio/scripts/preload-istio-images.sh
  istioctl install -y -f istio/istio-nodeport.yaml \
    --set values.global.imagePullPolicy=IfNotPresent
  kubectl rollout restart deployment/istiod -n istio-system

EOF
fi
exit 1
