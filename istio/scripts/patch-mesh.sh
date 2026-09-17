#!/usr/bin/env bash
set -euo pipefail

patch_mesh_file() {
  local mesh="$1"
  local discovery="${ISTIOD_DISCOVERY_ADDR:-istiod.istio-system.svc:31215}"

  if [[ ! -f "${mesh}" ]]; then
    echo "missing ${mesh}" >&2
    exit 1
  fi

  if grep -q '^  discoveryAddress:' "${mesh}"; then
    sed -i.bak "s|^  discoveryAddress:.*|  discoveryAddress: ${discovery}|" "${mesh}"
  else
    sed -i.bak "/^defaultConfig:/a\\
  discoveryAddress: ${discovery}
" "${mesh}"
  fi

  if grep -q 'ISTIO_META_SNI:' "${mesh}"; then
    sed -i.bak 's|ISTIO_META_SNI:.*|ISTIO_META_SNI: istiod.istio-system.svc|' "${mesh}"
  elif grep -q 'proxyMetadata:' "${mesh}"; then
    sed -i.bak '/proxyMetadata:/a\
    ISTIO_META_SNI: istiod.istio-system.svc
' "${mesh}"
  fi

  rm -f "${mesh}.bak"
}

patch_cluster_env() {
  local envfile="$1"
  local network_id="$2"

  if [[ ! -f "${envfile}" ]]; then
    echo "missing ${envfile}" >&2
    exit 1
  fi

  if grep -q "^ISTIO_META_NETWORK=" "${envfile}"; then
    sed -i.bak "s|^ISTIO_META_NETWORK=.*|ISTIO_META_NETWORK='${network_id}'|" "${envfile}"
  else
    echo "ISTIO_META_NETWORK='${network_id}'" >> "${envfile}"
  fi

  rm -f "${envfile}.bak"
}

patch_mesh_network() {
  local mesh="$1"
  local network_id="$2"

  if grep -q 'ISTIO_META_NETWORK:' "${mesh}"; then
    sed -i.bak "s|ISTIO_META_NETWORK:.*|ISTIO_META_NETWORK: ${network_id}|" "${mesh}"
  elif grep -q 'proxyMetadata:' "${mesh}"; then
    sed -i.bak "/proxyMetadata:/a\\
    ISTIO_META_NETWORK: ${network_id}
" "${mesh}"
  fi

  rm -f "${mesh}.bak"
}
