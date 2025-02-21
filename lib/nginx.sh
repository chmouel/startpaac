# shellcheck shell=bash
install_nginx() {
  local release_yaml
  show_step "Installing nginx ingress"
  release_yaml=$(cache_yaml_file nginx https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml)
  kubectl apply -f "${release_yaml}" >/dev/null
  kubectl -n ingress-nginx annotate ingressclasses nginx ingressclass.kubernetes.io/is-default-class="true" --overwrite=true
  wait_for_it ingress-nginx ingress-nginx-controller
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
