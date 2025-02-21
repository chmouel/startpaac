# shellcheck shell=bash
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

generate_certs_minica() {
  local domain="$1"
  [[ -e ${CERT_DIR}/${domain}/cert.pem ]] && return 0
  mkdir -p ${CERT_DIR}
  pass show minica/cert >${CERT_DIR}/minica.pem
  pass show minica/key >${CERT_DIR}/minica-key.pem
  (cd ${CERT_DIR} && minica -domains ${domain})
}
