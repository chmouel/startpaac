# 🚀 StartPAAC - All in one setup for Pipelines as Code on Kind

`startpaac` is a script to set up and configure Pipelines as Code (PAC) on a
Kubernetes cluster using Kind. It supports installing various components such
as Nginx, Tekton, and Forgejo, and configuring PAC with secrets.

Components that get installed are:

- Kind cluster
- Nginx ingress gateway
- Forgejo for local dev
- Docker registry to push images to.
- Tekton latest release
- Tekton dashboard latest
- PAC using ko from your local revision

## Prerequisites

- [Kind](https://kind.sigs.k8s.io/)
- [Helm](https://helm.sh/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [ko](https://github.com/google/ko)
- [pass](https://www.passwordstore.org/) (optional, for managing secrets)
- GNU Tools (ie for osx/bsd use the one from homebrew like
[coreutils](https://formulae.brew.sh/formula/coreutils) and
[sed](https://formulae.brew.sh/formula/gnu-sed#default) and configure them in
your path).

## Configuration

Create a configuration file at `$HOME/.config/startpaac/config` with the following content:

```sh
# Set your configuration here
#
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
## Hosts
# setup a wildcard dns *.lan.mydomain.com to go to your TARGET_HOST vm
# DOMAIN_NAME=lan.mydomain.com
# PAAC=paac.${DOMAIN_NAME}
# REGISTRY=registry.${DOMAIN_NAME}
# KO_EXTRA_FLAGS=() # extra ko flags for example --platform linux/arm64 --insecure-registry
# FORGE_HOST=gitea.${DOMAIN_NAME}
# DASHBOARD=dashboard.${DASHBOARD}
#
# Example:
# TARGET_HOST=civuole.lan
# KO_EXTRA_FLAGS=(--insecure-registry --platform linux/arm64)
# DOMAIN_NAME=vm.lan
# PAAC=paac.${DOMAIN_NAME}
# REGISTRY=registry.${DOMAIN_NAME}
# FORGE_HOST=gitea.${DOMAIN_NAME}
# TARGET_BIND_IP=192.168.1.5
# DASHBOARD=dashboard.${DOMAIN_NAME}
# PAC_DIR=$GOPATH/src/github.com/openshift-pipelines/pac/main
```

## Secrets Management

### Using `pass`

If you prefer to manage your secrets using `pass`, set the `PAC_PASS_SECRET_FOLDER` variable in your configuration file to the path of your secrets folder in `pass`. The folder should contain the following files:

- `github-application-id`
- `github-private-key`
- `smee`
- `webhook.secret`

Example structure:

```
github/apps/my-app
├── github-application-id
├── github-private-key
├── smee
└── webhook.secret
```

### Using Plain Text

Alternatively, you can store your secrets in plain text files. Set the `PAC_SECRET_FOLDER` variable in your configuration file to the path of your secrets folder. The folder should have the same structure as the `pass` folder, but the files should be in plain text.

Example structure:

```
~/path/to/secrets
├── github-application-id
├── github-private-key
├── smee
└── webhook.secret
```

## Usage

Run the script with the desired options:

```sh
./startpaac [options]
```

### Options

- `-a|--all`                Install everything
- `-A|--all-but-kind`       Install everything but kind
- `-k|--kind`               (Re)Install Kind
- `-g|--install-forge`      Install Forgejo
- `-c|--component`          Deploy a component (controller, watcher, webhook)
- `-p|--install-paac`       Deploy and configure PAC
- `-h|--help`               Show help message
- `-s|--sync-kubeconfig`    Sync kubeconfig from the remote host
- `-G|--start-user-gosmee`  Start gosmee locally for user $USER
- `-S|--github-second-ctrl` Deploy second controller for GitHub
- `--install-nginx`         Install Nginx
- `--install-dashboard`     Install Tekton dashboard
- `--install-tekton`        Install Tekton
- `--install-custom-crds`   Install custom CRDs
- `--second-secret=SECRET`  Pass name for the second controller secret, default: ${secondSecret}
- `--stop-kind`             Stop Kind

## Examples

### Install Everything

```sh
./startpaac --all
```

### Install PAC and Configure

```sh
./startpaac --install-paac
```

### Install Nginx

```sh
./startpaac --install-nginx
```

### Install Tekton

```sh
./startpaac --install-tekton
```

### Install Custom CRDs

```sh
./startpaac --install-custom-crds
```

### Deploy a Specific Component

```sh
./startpaac --component controller
```

### Sync Kubeconfig from Remote Host

```sh
./startpaac --sync-kubeconfig
```

### Start User Gosmee

```sh
./startpaac --start-user-gosmee
```

### Deploy Second Controller for GitHub

```sh
./startpaac --github-second-ctrl
```

## ZSH Completion

There is a [ZSH completion script](./_startpaac) that can get installed in your
path for completion.

## Author

Chmouel Boudjnah <chmouel@chmouel.com>
