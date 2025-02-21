# shellcheck shell=bash
install_kind() {
  [[ "${TARGET_HOST}" != local ]] && check_kind
  stop_kind
  show_step "Creating kind cluster"
  local kfilename=${SP}/lib/kind/kind.yaml
  sed -e "s/%REGISTRY%/${REGISTRY}/" -e "s/%TARGET_BIND_IP%/${TARGET_BIND_IP}/" ${kfilename} >$TMPFILE
  case ${TARGET_HOST} in
  local)
    kind create cluster --kubeconfig ${KUBECONFIG} --config ${TMPFILE}
    ;;
  *)
    scp -q "${TMPFILE}" "${TARGET_HOST}":/tmp/.kind.yaml
    ssh -q "${TARGET_HOST}" kind create cluster --kubeconfig .kube/$(basename ${KUBECONFIG}) --config /tmp/.kind.yaml
    ;;
  esac
}

stop_kind() {
  show_step "Stopping Kind"

  case ${TARGET_HOST} in
  local)
    kind delete cluster --name kind
    ;;
  *)
    ssh -q "${TARGET_HOST}" kind delete cluster --name kind
    ;;
  esac
  rm -f "${KUBECONFIG}"
}

check_kind() {
  output=$(ssh "${TARGET_HOST}" which kind || true)
  [[ "${output}" == *"not found" ]] && {
    echo "Kind is not installed on ${TARGET_HOST}"
    exit 1
  } || true
}

sync_kubeconfig() {
  [[ ${TARGET_HOST} == local ]] && return
  show_step "Syncing kubeconfig"
  scp -q "${TARGET_HOST}":.kube/$(basename ${KUBECONFIG}) "${KUBECONFIG}"
  echo "${KUBECONFIG} from ${TARGET_HOST} has been updated"
  chmod 600 "${KUBECONFIG}"
}
