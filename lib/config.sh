# shellcheck shell=bash
CONFIG_FILE=${STARTPAAC_CONFIG_FILE:-$HOME/.config/startpaac/config}

if [[ -e "${CONFIG_FILE}" ]]; then
  source "${CONFIG_FILE}" # shellcheck disable=SC1090
else
  mkdir -p $(dirname $CONFIG_FILE)
  echo "Creating sample $HOME/.config/startpaac/config read the comment in the file and edit it with your configuration"
  cat <<EOF >"${CONFIG_FILE}"
# PAC_DIR is the path to the pipelines-as-code directory, it will try to detect it otherwise
# PAC_DIR=~/path/to/pipelines-as-code
#
# PAC_PASS_SECRET_FOLDER is the path to a folder in https://passwordstore.org/
# where you have your pac secrets. The folder contains those keys:
# github/apps/my-app
# ├── github-application-id
# ├── github-private-key
# ├── smee
# └── webhook.secret
# github-application-id and github-private-key are the github application id and private key when you create your github app
# smee is the smee.io or https://hook.pipelinesascode.com generated webhook URL as set in your github apps.
# webhook.secret is the shared secret as set in your github apps.
# PAC_PASS_SECRET_FOLDER=github/apps/my-app
#
# PAC_SECRET_FOLDER is an alternative to PASS_SECRET_FOLDER where you have your
# pac secrets in plain text. The folder has the same structure as the
# PASS_SECRET_FOLDER the only difference is that the files are in plain text.
#
# PAC_SECRET_FOLDER=~/path/to/secrets
#
# TARGET_HOST is your vm where kind will be running, you need to have kind working there
# set as local and unset all other variable to have it running on your local VM
# TARGET_HOST=my.vm.lan
#
# KO_EXTRA_FLAGS are the extra flags to pass to ko
#
# KO_EXTRA_FLAGS=() # extra ko flags for example --platform linux/arm64 --insecure-registry
## Hosts (not needed if TARGET_HOST is set to local)
# setup a wildcard dns *.lan.mydomain.com to go to your TARGET_HOST vm
# tips: if you don't want to install a dns server you can simply use
# https://nextdns.io to let you create wildcard dns for your local network.
#
# DOMAIN_NAME=lan.mydomain.com
# PAAC=paac.\${DOMAIN_NAME}
# REGISTRY=registry.\${DOMAIN_NAME}
# FORGE_HOST=gitea.\${DOMAIN_NAME}
# DASHBOARD=dashboard.\${DASHBOARD}
#
# Example:
# TARGET_HOST=civuole.lan
# KO_EXTRA_FLAGS=(--insecure-registry --platform linux/arm64)
# DOMAIN_NAME=vm.lan
# PAAC=paac.\${DOMAIN_NAME}
# REGISTRY=registry.\${DOMAIN_NAME}
# FORGE_HOST=gitea.\${DOMAIN_NAME}
# TARGET_BIND_IP=192.168.1.5
# DASHBOARD=dashboard.\${DOMAIN_NAME}
# PAC_DIR=\$GOPATH/src/github.com/openshift-pipelines/pac/main
EOF
  exit 1
fi
set +x
