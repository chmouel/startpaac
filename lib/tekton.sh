# shellcheck shell=bash
install_tekton() {
  local release_yaml
  show_step "Deploying Tekton"
  release_yaml=$(cache_yaml_file tekton https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml)
  kubectl apply --filename "${release_yaml}" >/dev/null
  wait_for_it tekton-pipelines tekton-pipelines-webhook
  kubectl patch configmap -n tekton-pipelines --type merge -p '{"data":{"enable-step-actions": "true"}}' feature-flags
}

install_dashboard() {
  local release_yaml
  show_step "Deploying Tekton Dashboard"
  release_yaml=$(cache_yaml_file dashboard https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml)
  kubectl apply --filename "${release_yaml}" >/dev/null
  create_ingress tekton-pipelines tekton-dashboard ${DASHBOARD} 9097
}
