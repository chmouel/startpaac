#!/usr/bin/env bash
# shellcheck disable=SC2059
CERT_DIR=${CERT_DIR:-/tmp/certs}

echo_color() {
  local echo=
  [[ ${1-""} == "-n" ]] && {
    echo="-n"
    shift
  }
  local color=$1
  local text=${2:-}
  case ${color} in
  red)
    echo ${echo} -e "\033[31m${text}\033[0m"
    ;;
  brightred)
    echo ${echo} -e "\033[1;31m${text}\033[0m"
    ;;
  green)
    echo ${echo} -e "\033[32m${text}\033[0m"
    ;;
  brightgreen)
    echo ${echo} -e "\033[1;32m${text}\033[0m"
    ;;
  blue)
    echo ${echo} -e "\033[34m${text}\033[0m"
    ;;
  brightblue)
    echo ${echo} -e "\033[1;34m${text}\033[0m"
    ;;
  brightwhite)
    echo ${echo} -e "\033[1;37m${text}\033[0m"
    ;;
  yellow)
    echo ${echo} -e "\033[33m${text}\033[0m"
    ;;
  brightyellow)
    echo ${echo} -e "\033[1;33m${text}\033[0m"
    ;;
  cyan)
    echo ${echo} -e "\033[36m${text}\033[0m"
    ;;
  bryightcyan)
    echo ${echo} -e "\033[1;36m${text}\033[0m"
    ;;
  purple)
    echo ${echo} -e "\033[35m${text}\033[0m"
    ;;
  brightcyan)
    echo ${echo} -e "\033[1;35m${text}\033[0m"
    ;;
  normal)
    echo ${echo} -e "\033[0m${text}\033[0m"
    ;;
  reset)
    echo ${echo} -e "\033[0m"
    ;;
  esac
}

show_step() {
  text="$1"
  length=$((${#text} + 4))

  # ANSI escape codes for colors
  green='\033[0;32m'
  blue='\033[0;34m'
  reset='\033[0m'

  # Top border
  printf "${green}╔${reset}" && printf "${green}═%.0s${reset}" $(seq 1 $((length - 2))) && printf "${green}╗${reset}\n"

  # Text with borders (using blue color)
  printf "${green}║ ${blue}%s${green} ║${reset}\n" "$text"

  # Bottom border
  printf "${green}╚${reset}" && printf "${green}═%.0s${reset}" $(seq 1 $((length - 2))) && printf "${green}╝${reset}\n"
}

create_tls_secret() {
  local host=$1
  local sec_name=$2
  local namespace=$3
  local key_file=${CERT_DIR}/${host}/key.pem
  local cert_file=${CERT_DIR}/${host}/cert.pem
  generate_certs_minica ${host}
  kubectl delete secret ${sec_name} -n ${namespace} || true
  kubectl create secret tls ${sec_name} --key ${key_file} --cert ${cert_file} -n ${namespace}
}

create_ingress() {
  local namespace=$1
  local component=$2
  local host=$3
  local targetPort=$4
  local sec_name=${component}-tls
  create_tls_secret ${host} ${sec_name} ${namespace}

  echo "Creating ingress on $(echo_color brightgreen https://${host}) for ${component}:${targetPort} in ${namespace}"
  cat <<EOF | kubectl apply -f -
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "${component}"
  namespace: "${namespace}"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - "${host}"
      secretName: "${sec_name}"
  rules:
    - host: "${host}"
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: "${component}"
                port:
                  number: ${targetPort}
EOF
}

generate_certs_minica() {
  local domain="$1"
  [[ -e ${CERT_DIR}/${domain}/cert.pem ]] && return 0
  mkdir -p ${CERT_DIR}
  pass show minica/cert >${CERT_DIR}/minica.pem
  pass show minica/key >${CERT_DIR}/minica-key.pem
  (cd ${CERT_DIR} && minica -domains ${domain})
}

wait_for_it() {
  local namespace=$1
  local component=$2
  echo_color -n brightgreen "Waiting for ${component} to be ready in ${namespace}: "
  i=0
  while true; do
    [[ ${i} == 120 ]] && exit 1
    ep=$(kubectl get ep -n "${namespace}" "${component}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    [[ -n ${ep} ]] && break
    sleep 2
    echo_color -n brightwhite "."
    i=$((i + 1))
  done
  echo_color brightgreen "OK"
}

check_tools() {
  local tools=(
    "kubectl"
    "helm"
    "curl"
    "docker"
    "kind"
    "ko"
    "base64"
    "ssh"
    "scp"
    "sed"
    "mktemp"
    "readlink"
  )
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      echo "Error: $tool is not installed or not in PATH."
      return 1
    fi
  done
  if [[ -n ${PAC_PASS_SECRET_FOLDER:-""} ]]; then
    if ! command -v pass &>/dev/null; then
      echo "Error: pass is not installed or not in PATH and you have the PAC_PASS_SECRET_FOLDER variable set."
      echo "Use PAC_SECRET_FOLDER instead if you want a folder instead of pass."
      return 1
    fi
  fi
  return 0
}
