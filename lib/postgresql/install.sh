#!/usr/bin/env bash
# Copyright 2024 Chmouel Boudjnah <chmouel@chmouel.com>
set -eufo pipefail
NS=postgresql
fpath=$(dirname "$0")
# shellcheck disable=SC1091
source "${fpath}"/../common.sh

kubectl create namespace ${NS} 2>/dev/null || true

helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
helm install --wait -f ${fpath}/values.yaml \
  --replace \
  --create-namespace -n ${NS} postgresql bitnami/postgresql --version 13.2.27
