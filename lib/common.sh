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
    "pass"
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
  return 0
}

show_config() {
  cat <<EOF
Using configuration on ${TARGET_HOST}:

DOMAIN_NAME: ${DOMAIN_NAME},
TARGET_BIND_IP: ${TARGET_BIND_IP}
PAAC: https://${PAAC}
REGISTRY: https://${REGISTRY}
FORGE_HOST: https://${FORGE_HOST}
DASHBOARD: https://${DASHBOARD}
GOSMEE:
 gosmee client --saveDir /tmp/replay $(pass show ${PAC_PASS_SECRET_FOLDER}/smee) https://${PAAC}
EOF
}

cache_yaml_file() {
  local type="$1"
  local url="$2"
  local cache_dir="${HOME}/.cache/startpaac"
  local filename="${cache_dir}/${type}.yaml"
  local week_in_seconds=604800 # 7 days * 24 hours * 60 minutes * 60 seconds
  mkdir -p ${cache_dir}

  # Get file modification time in a cross-platform way
  get_mtime() {
    if type -p gstat >/dev/null; then
      gstat -c %Y "$1"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      stat -f %m "$1"
    else
      stat -c %Y "$1"
    fi
  }

  # Check if file exists and is older than a week
  if [[ ! -e ${filename} ]] ||
    [[ $(($(date +%s) - $(get_mtime "${filename}"))) -gt ${week_in_seconds} ]]; then
    curl --progress-bar -L --location --retry 10 --retry-max-time 10 -o ${filename} ${url}
  fi
  echo ${filename}
}

install_registry() {
  show_step "Installing registry"
  "${SP}"/lib/registry/install.sh ${REGISTRY}
}

function install_forgejo() {
  show_step "Installing Forgejo"
  "${SP}"/lib/forgejo/install.sh ${1}
}

function start_user_gosmee() {
  local service=${1:-"gosmee"}
  local smeeurl=${2:-}
  local controllerURL=${3:-}
  type -p systemctl >/dev/null 2>/dev/null && return
  [[ -e ${HOME}/.config/systemd/user/${service}.service ]] || {
    if [[ -n ${smeeurl} ]]; then
      show_step "Run gosmee manually"
      echo "gosmee client --saveDir /tmp/replay ${smeeurl} https://${controllerURL}"
    else
      echo "Skipping running gosmee: cannot find ${HOME}/.config/systemd/user/${service}.service"
    fi
    return
  }
  show_step "Running ${service} systemd service locally for user $USER"
  systemctl --user restart ${service} >/dev/null 2>&1 || true
  systemctl --user status ${service} -o cat
  if kubectl get deployment gosmee-ghe -n "${PAC_CONTROLLER_TARGET_NS}" >/dev/null 2>&1; then
    kubectl scale deployment gosmee-ghe -n "${PAC_CONTROLLER_TARGET_NS}" --replicas=0 >/dev/null || true
    echo "Deployment $(echo_color red gosmee-ghe) has been scaled down"
  fi
}

function install_custom_crds() {
  show_step "Installing custom CRDs"
  [[ -d $HOME/Sync/paac/crds ]] || {
    echo "Cannot find $HOME/Sync/paac/crds"
    exit 1
  }
  kubectl apply -f $HOME/Sync/paac/crds
}

function set_namespace() {
  local ns=${1:-"default"}
  kubectl config set-context --current --namespace=${ns}
}
