#!/usr/bin/env bash
# Copyright 2024 Chmouel Boudjnah <chmouel@chmouel.com>
set -eufo pipefail
NS=registry
fpath=$(dirname "$0")
# shellcheck disable=SC1091
source "${fpath}"/../common.sh

REGISTRY=${1}
[[ -z ${REGISTRY} ]] && {
  echo "Usage: $0 <registry>"
  exit 1
}
TARGET_HOST=${2:-local}

if [[ ${1:-""} == "-r" ]]; then
  kubectl delete ns ${NS} || true
fi

kubectl create namespace ${NS} 2>/dev/null || true

{ helm repo list | grep -q twun.io; } || helm repo add twuni https://helm.twun.io
[[ -z $(helm status -n ${NS} docker-registry) ]] &&
  helm install --wait --set garbageCollect.enabled=true docker-registry twuni/docker-registry --namespace ${NS}
create_ingress ${NS} docker-registry ${REGISTRY} 5000

show_step "Add annotations to the ingress controller"
for annotations in "nginx.ingress.kubernetes.io/proxy-body-size=0" \
  "nginx.ingress.kubernetes.io/proxy-read-timeout=600" \
  "nginx.ingress.kubernetes.io/proxy-send-timeout=600" \
  "kubernetes.io/tls-acme=true"; do
  kubectl annotate ingress -n ${NS} docker-registry "${annotations}"
done

show_step "Copying self certs on the control plane"
prefix=()
if [[ ${TARGET_HOST} != local ]]; then
  generate_certs_minica ${REGISTRY}
  scp -qr ${CERT_DIR} ${TARGET_HOST}:/tmp/$(basename ${CERT_DIR})
  prefix=(ssh -q "${TARGET_HOST}" -t)
  CERT_DIR=/tmp/$(basename ${CERT_DIR})
fi

show_step "Copying self certs to the control plane"
"${prefix[@]}" docker cp ${CERT_DIR}/minica.pem kind-control-plane:/etc/ssl/certs/minica.pem
"${prefix[@]}" docker cp ${CERT_DIR}/${REGISTRY}/cert.pem kind-control-plane:/etc/ssl/certs/${REGISTRY}.crt
"${prefix[@]}" docker cp ${CERT_DIR}/${REGISTRY}/key.pem kind-control-plane:/etc/ssl/private/${REGISTRY}.key
"${prefix[@]}" docker exec kind-control-plane systemctl restart containerd

show_step "Waiting for registry ${REGISTRY} to be ready..."
until curl -o/dev/null --fail -k -s "https://${REGISTRY}/v2/"; do
  echo_color -n brightwhite "."
  sleep 5
done
echo ""
echo "Registry ${REGISTRY} is up and running."
