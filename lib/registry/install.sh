#!/usr/bin/env bash
# Copyright 2024 Chmouel Boudjnah <chmouel@chmouel.com>
set -eufo pipefail

NS=${1:-registry}
REGISTRY=${2:-""}
fpath=$(dirname "$0")
# shellcheck disable=SC1091
source "${fpath}"/../common.sh

install_registry() {
  local namespace=$1
  local registry=$2

  if [[ -z ${registry} ]]; then
    echo "You need to specify a REGISTRY"
    exit 1
  fi

  if [[ ${3:-""} == "-r" ]]; then
    kubectl delete ns ${namespace} || true
  fi

  kubectl create namespace ${namespace} 2>/dev/null || true

  { helm repo list | grep -q twun.io; } || helm repo add twuni https://helm.twun.io
  [[ -z $(helm status -n ${namespace} docker-registry) ]] &&
    helm install --wait --set garbageCollect.enabled=true docker-registry twuni/docker-registry --namespace ${namespace}
  create_ingress ${namespace} docker-registry ${registry} 5000

  show_step "Add annotations to the ingress controller"
  for annotations in "nginx.ingress.kubernetes.io/proxy-body-size=0" \
    "nginx.ingress.kubernetes.io/proxy-read-timeout=600" \
    "nginx.ingress.kubernetes.io/proxy-send-timeout=600" \
    "kubernetes.io/tls-acme=true"; do
    kubectl annotate ingress -n ${namespace} docker-registry "${annotations}"
  done
}

install_registry ${NS} ${REGISTRY}
