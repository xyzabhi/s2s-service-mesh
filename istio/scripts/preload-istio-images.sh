#!/usr/bin/env bash
# Pull Istio images on the host (where VPN/proxy often works) and load istiod into Kind.
# Sidecars use the same proxyv2 image via Docker Compose on the host — no in-cluster pull.
set -euo pipefail

ISTIO_TAG="${ISTIO_TAG:-1.31.0}"
ISTIO_HUB="${ISTIO_HUB:-docker.io/istio}"
PULL_RETRIES="${PULL_RETRIES:-3}"

PILOT_IMAGE="${ISTIO_HUB}/pilot:${ISTIO_TAG}"
PROXY_IMAGE="${ISTIO_HUB}/proxyv2:${ISTIO_TAG}"

resolve_kind_cluster() {
  if [[ -n "${KIND_CLUSTER:-}" ]]; then
    echo "${KIND_CLUSTER}"
    return 0
  fi
  if kind get clusters 2>/dev/null | grep -qx kind; then
    echo kind
    return 0
  fi
  local first
  first="$(kind get clusters 2>/dev/null | head -1 || true)"
  if [[ -n "${first}" ]]; then
    echo "${first}"
    return 0
  fi
  echo kind
}

KIND_CLUSTER="$(resolve_kind_cluster)"

pull_image() {
  local ref="$1"
  local attempt=1
  while [[ "${attempt}" -le "${PULL_RETRIES}" ]]; do
    echo "Pulling ${ref} (attempt ${attempt}/${PULL_RETRIES})..."
    if docker pull "${ref}"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  cat >&2 <<EOF

Failed to pull: ${ref}

Corporate laptop checklist:
  1. Connect company VPN (if required for Docker Hub).
  2. Export proxy if IT gave you one, then retry:
       export HTTPS_PROXY=http://proxy.company:8080
       export HTTP_PROXY=http://proxy.company:8080
       export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
  3. Or use an internal mirror (ask IT), then:
       export ISTIO_HUB=registry.company.com/istio
       export ISTIO_TAG=1.31.0
       ./istio/scripts/preload-istio-images.sh

EOF
  return 1
}

tag_aliases() {
  local pilot="${PILOT_IMAGE}"
  local proxy="${PROXY_IMAGE}"
  if [[ "${pilot}" != "docker.io/istio/pilot:${ISTIO_TAG}" ]]; then
    docker tag "${pilot}" "docker.io/istio/pilot:${ISTIO_TAG}" || true
  fi
  if [[ "${proxy}" != "docker.io/istio/proxyv2:${ISTIO_TAG}" ]]; then
    docker tag "${proxy}" "docker.io/istio/proxyv2:${ISTIO_TAG}" || true
  fi
  docker tag "${proxy}" "istio/proxyv2:${ISTIO_TAG}" || true
  docker tag "${pilot}" "istio/pilot:${ISTIO_TAG}" || true
}

kind_load_one() {
  local img="$1"
  echo "Loading ${img} into kind cluster '${KIND_CLUSTER}'..."

  if kind load docker-image "${img}" --name "${KIND_CLUSTER}"; then
    return 0
  fi

  echo "kind load docker-image failed; trying image-archive (often works on corp Docker)..." >&2
  local tar
  tar="$(mktemp "/tmp/istio-kind-load-XXXXXX.tar")"
  trap 'rm -f "${tar}"' RETURN
  docker save "${img}" -o "${tar}"
  kind load image-archive "${tar}" --name "${KIND_CLUSTER}"
}

load_pilot_into_kind() {
  if ! command -v kind >/dev/null 2>&1; then
    echo "kind not found; skipping kind load (only needed for istiod in Kubernetes)."
    return 0
  fi
  if ! kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER}"; then
    echo "Kind cluster '${KIND_CLUSTER}' not found. Clusters:" >&2
    kind get clusters >&2 || true
    echo "Create one: kind create cluster --config kind-config.yaml" >&2
    return 1
  fi

  local candidates=(
    "${PILOT_IMAGE}"
    "docker.io/istio/pilot:${ISTIO_TAG}"
    "istio/pilot:${ISTIO_TAG}"
  )
  local img
  for img in "${candidates[@]}"; do
    if docker image inspect "${img}" >/dev/null 2>&1; then
      if kind_load_one "${img}"; then
        echo "Loaded into kind: ${img}"
        return 0
      fi
    fi
  done

  cat >&2 <<EOF
Failed to load pilot image into kind cluster '${KIND_CLUSTER}'.

Try manually:
  docker pull docker.io/istio/pilot:${ISTIO_TAG}
  docker save docker.io/istio/pilot:${ISTIO_TAG} -o /tmp/pilot.tar
  kind load image-archive /tmp/pilot.tar --name ${KIND_CLUSTER}

Checks:
  docker info
  df -h /
  kind get clusters
  docker exec ${KIND_CLUSTER}-control-plane crictl images | head

If disk is full, run: docker system prune -f
If Kind is broken: kind delete cluster --name ${KIND_CLUSTER} && kind create cluster --config kind-config.yaml

EOF
  return 1
}

main() {
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running or your user lacks permission (try: newgrp docker)." >&2
    exit 1
  fi

  pull_image "${PILOT_IMAGE}"
  pull_image "${PROXY_IMAGE}"
  tag_aliases
  load_pilot_into_kind
  echo "Images ready (kind cluster: ${KIND_CLUSTER}):"
  echo "  istiod:  ${PILOT_IMAGE}"
  echo "  sidecar: ${PROXY_IMAGE}"
}

main "$@"
