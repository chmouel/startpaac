#!/usr/bin/env bash
# Copyright 2024 Chmouel Boudjnah <chmouel@chmouel.com>
set -eufo pipefail
NS=${1:-forgejo}
FORGE_HOST=${2:-""}
fpath=$(dirname "$0")
# shellcheck disable=SC1091
source "${fpath}"/../common.sh

install_forgejo() {
  local namespace=$1
  local forge_host=$2
  local forge_secret_name=forge-tls

  if [[ -z ${forge_host} ]]; then
    echo "You need to specify a FORGE_HOST"
    exit 1
  fi

  kubectl create namespace ${namespace} 2>/dev/null || true
  create_tls_secret ${forge_host} ${forge_secret_name} ${namespace}

  helm uninstall forgejo -n ${namespace} >/dev/null || true
  helm install --wait -f ${fpath}/values.yaml \
    --replace \
    --set ingress.hosts[0].host=${forge_host} \
    --set ingress.tls[0].hosts[0]=${forge_host} \
    --set ingress.tls[0].secretName=${forge_secret_name} \
    --create-namespace -n ${namespace} forgejo oci://codeberg.org/forgejo-contrib/forgejo
}

install_forgejo ${NS} ${FORGE_HOST}
