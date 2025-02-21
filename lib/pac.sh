# shellcheck shell=bash
install_pac() {
  if [[ -n ${1:-""} ]]; then
    show_step "Deploying PAC $1"
  else
    show_step "Deploying PAC"
  fi
  local c=config
  case ${1:-""} in
  controller)
    c=${c}/400-controller.yaml
    ;;
  watcher)
    c=${c}/500-watcher.yaml
    ;;
  webhook)
    c=${c}/600-webhook.yaml
    ;;
  esac
  env KO_DOCKER_REPO="${REGISTRY}" ko apply -f "${c}" -B --sbom=none "${KO_EXTRA_FLAGS[@]}"

  for controller in ${SCALE_DOWNS_CONTROLLER}; do
    kubectl scale deployment -n pipelines-as-code -l app.kubernetes.io/name=${controller} --replicas=0
  done
}

create_pac_secret() {
  folder=$1
  shift
  read -a read_method <<<"$@"

  kubectl delete secret pipelines-as-code-secret -n pipelines-as-code 2>/dev/null || true
  kubectl create secret generic pipelines-as-code-secret -n pipelines-as-code
  for passk in github-application-id github-private-key webhook.secret; do
    if [[ ${passk} == *-key ]]; then
      b64d=$("${read_method[@]}" "${folder}"/${passk} | base64 -w0)
    else
      b64d=$(echo -n $("${read_method[@]}" "${folder}"/${passk}) | base64 -w0)
    fi
    kubectl patch secret -n pipelines-as-code -p "{\"data\":{\"${passk}\": \"${b64d}\"}}" \
      --type merge pipelines-as-code-secret >/dev/null
  done
}

configure_pac() {
  show_step "Configuring PAC"

  create_ingress pipelines-as-code pipelines-as-code-controller "${PAAC}" 8080

  kubectl patch configmap -n pipelines-as-code -p \
    "{\"data\":{\"bitbucket-cloud-check-source-ip\": \"false\"}}" pipelines-as-code
  kubectl patch configmap -n pipelines-as-code -p \
    "{\"data\":{\"tekton-dashboard-url\": \"http://${DASHBOARD}\"}}" --type merge pipelines-as-code
  kubectl patch configmap -n pipelines-as-code -p \
    '{"data":{"catalog-1-id": "custom", "catalog-1-name": "tekton", "catalog-1-url": "https://api.hub.tekton.dev/v1"}}' \
    --type merge pipelines-as-code

  if [[ -n ${PAC_PASS_SECRET_FOLDER:-""} ]]; then
    echo "Installing PAC secrets from pass folder: ${PAC_PASS_SECRET_FOLDER}"
    create_pac_secret ${PAC_PASS_SECRET_FOLDER} pass show
  elif [[ -n ${PAC_SECRET_FOLDER:-""} ]]; then
    echo "Installing PAC secrets from plain text folder: ${PAC_SECRET_FOLDER}"
    create_pac_secret ${PAC_SECRET_FOLDER} cat
  else
    cat <<EOF
  **No secret has been installed**

  You need to either create a pass https://www.passwordstore.org/ folder with
  github-application-id github-private-key webhook.secret information in there
  and export the PAC_PASS_SECRET_FOLDER variable to that folder

  Or have a plain text folder with the same structure and export the
  PAC_SECRET_FOLDER variable

  Or have nothing and install the secrets manually after running the startpaac
  script.
EOF
    kubectl delete secret -n pipelines-as-code pipelines-as-code-secret >/dev/null 2>/dev/null || true
  fi
}

create_paac_secret() {
  local secretname=$1
  local passfolder=$2
  echo "Installing PAC secrets"
  kubectl delete secret ${secretname} -n pipelines-as-code 2>/dev/null || true
  kubectl create secret generic ${secretname} -n pipelines-as-code
  for passk in github-application-id github-private-key webhook.secret; do
    if [[ ${passk} == *-key ]]; then
      b64d=$(pass show "${passfolder}"/${passk} | base64 -w0)
    else
      b64d=$(echo -n $(pass show "${passfolder}"/${passk}) | base64 -w0)
    fi
    kubectl patch secret -n pipelines-as-code -p "{\"data\":{\"${passk}\": \"${b64d}\"}}" --type merge ${secretname} >/dev/null
  done

}

function install_github_second_ctrl() {
  local pass_env_file
  show_step "Installing GHE second controller for github"
  export PAC_CONTROLLER_LABEL=${PAC_CONTROLLER_LABEL:-"ghe"}
  export PAC_CONTROLLER_SECRET=${PAC_CONTROLLER_SECRET:-${PAC_CONTROLLER_LABEL}-secret}
  export PAC_CONTROLLER_CONFIGMAP=${PAC_CONTROLLER_CONFIGMAP:-${PAC_CONTROLLER_LABEL}-configmap}
  export PAC_CONTROLLER_TARGET_NS="pipelines-as-code"
  export PAC_CONTROLLER_IMAGE=${PAC_CONTROLLER_IMAGE:-"ko"}
  local kind_url=http://${DASHBOARD}
  [[ -z ${PAC_PASS_SECOND_FOLDER} ]] && {
    echo "You need to set the PAC_PASS_SECOND_FOLDER variable in your ${CONFIG_FILE}"
    exit 1
  }
  local password_store_path=${PASSWORD_STORE_DIR:-$HOME/.password-store}
  [[ -d ${password_store_path}/${PAC_PASS_SECOND_FOLDER} ]] || {
    echo "secondSecret ${PAC_PASS_SECOND_FOLDER} does not exist"
    echo "set environment variable PAC_PASS_SECOND_FOLDER to the correct pass folder"
    exit 1
  }
  echo "Using pass_secret_folder: ${PAC_PASS_SECOND_FOLDER}"
  PAC_CONTROLLER_SMEE_URL=$(pass show ${pass_env_file} | sed -n '/SMEE_URL/ { s/.*=//;p}')
  export PAC_CONTROLLER_SMEE_URL
  hack/second-controller.py ${PAC_CONTROLLER_LABEL} | tee /tmp/.second.controller.debug.yaml | env KO_DOCKER_REPO="${REGISTRY}" ko apply -f- -B --sbom=none "${KO_EXTRA_FLAGS[@]}"
  kubectl patch configmap -n ${PAC_CONTROLLER_TARGET_NS} -p '{"data":{"application-name": "Pipelines as Code GHE"}}' ${PAC_CONTROLLER_CONFIGMAP}
  kubectl patch configmap -n ${PAC_CONTROLLER_TARGET_NS} -p "{\"data\":{\"tekton-dashboard-url\": \"${kind_url}\"}}" --type merge ${PAC_CONTROLLER_CONFIGMAP}
  kubectl patch configmap -n ${PAC_CONTROLLER_TARGET_NS} -p '{"data":{"catalog-2-id": "custom2", "catalog-2-name": "tekton", "catalog-2-url": "https://api.hub.tekton.dev/v1"}}' --type merge ${PAC_CONTROLLER_CONFIGMAP}
  kubectl delete secret ${PAC_CONTROLLER_SECRET} -n ${PAC_CONTROLLER_TARGET_NS} >/dev/null 2>/dev/null || true
  kubectl create secret generic ${PAC_CONTROLLER_SECRET} -n ${PAC_CONTROLLER_TARGET_NS} >/dev/null
  create_paac_secret ${PAC_CONTROLLER_SECRET} ${PAC_PASS_SECOND_FOLDER}
  local targetUrl=${PAC_CONTROLLER_LABEL}.${DOMAIN_NAME}
  if [[ ${DOMAIN_NAME} == "local" ]]; then
    targetUrl=${PAC_CONTROLLER_LABEL}.127.0.0.1.nip.io
  fi
  show_step "Creating ingress for ${PAC_CONTROLLER_LABEL} controller"
  create_ingress ${PAC_CONTROLLER_TARGET_NS} ${PAC_CONTROLLER_LABEL}-controller "${targetUrl}" 8080
  kubectl delete deployment -n ${PAC_CONTROLLER_TARGET_NS} gosmee-${PAC_CONTROLLER_LABEL} 2>/dev/null || true
  start_user_gosmee ghe ${PAC_CONTROLLER_SMEE_URL} "${targetUrl}"
}
