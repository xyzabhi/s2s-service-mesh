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
