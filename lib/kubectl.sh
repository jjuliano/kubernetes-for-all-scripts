# lib/kubectl.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 13
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

safe_kubectl() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to safe_kubectl()!' 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kubectl $*" "$fg_yellow"
    return 0
  fi


  check_binary kubectl && \
    kubectl "${@-}"
}

kubectl_install_resource_from_file() {
  log "Kubectl: Installing kubernetes resource ${orig_cwd-}/${1-} ..."

  check_files "${orig_cwd-}/${1-}" && \
    safe_kubectl apply -f "${orig_cwd-}/${1-}"
}


kubectl_create_db_bootstrap_file() {
  log "Kubectl: Creating db bootstrap file ..." "$ta_bold$fg_blue"

  if check_files \
    "${orig_cwd-}/k8s/bootstrapdb.sh" \
    "${orig_cwd-}/k8s/load_sql.sh" \
    "$(get_repos_dir)/keymaster/resources/keymaster_db.sql" \
    "$(get_repos_dir)/datastore/resources/db.sql" \
    "$(get_repos_dir)/migrator/resources/InitMetadataStore.sql"; then

    # Piping safe_kubectl into itself under --dry-run SIGPIPEs because log()
    # writes to stdout (as in the book). Skip the pipe and print the commands.
    if [[ -n ${dry_run-} ]]; then
      log "DRY-RUN: kubectl create configmap postgres-scripts ... | kubectl apply -f -" "$fg_yellow"
      log "DRY-RUN: kubectl create configmap postgres-init-sql ... | kubectl apply -f -" "$fg_yellow"
    else
      safe_kubectl create configmap postgres-scripts \
        --from-file=bootstrap.sh="${orig_cwd-}/k8s/bootstrapdb.sh" \
        --from-file=load_sql.sh="${orig_cwd-}/k8s/load_sql.sh" \
        --namespace myapp \
        --dry-run=client -o yaml | safe_kubectl apply -f -
      safe_kubectl create configmap postgres-init-sql \
        --from-file=keymaster_db.sql="$(get_repos_dir)/keymaster/resources/keymaster_db.sql" \
        --from-file=db.sql="$(get_repos_dir)/datastore/resources/db.sql" \
        --from-file=InitMetadataStore.sql="$(get_repos_dir)/migrator/resources/InitMetadataStore.sql" \
        --namespace myapp \
        --dry-run=client -o yaml | safe_kubectl apply -f -
    fi
  fi
}

kubectl_install_database() {
  log "Kubectl: Installing postgres ..." "$ta_bold$fg_blue"

  # The printed postgres.yaml references secret/db-auth. Ensure it exists.
  kubectl_install_resource_from_file k8s/db-auth.yaml

  kubectl_create_db_bootstrap_file

  kubectl_install_resource_from_file k8s/postgres.yaml

  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: skipping postgres readiness wait" "$fg_yellow"
    return 0
  fi

  log "Waiting until postgres container is running ..."
  safe_kubectl wait --for=condition=ready pod \
    --selector=app=postgres -n myapp --timeout=300s

  local POSTGRES_POD_NAME="$(kubectl get pods -n myapp \
    --selector=app=postgres \
    -o jsonpath='{.items[0].metadata.name}')"

  log "Waiting for PostgreSQL to accept connections ..."
  local DB_STATUS=""
  while [[ -z "${DB_STATUS-}" ]]; do
    DB_STATUS="$(kubectl logs ${POSTGRES_POD_NAME-} -n myapp \
      | grep -i "database system is ready to accept connections")"
    sleep 1
  done

  log "Creating databases and roles ..."
  safe_kubectl exec "${POSTGRES_POD_NAME-}" -n myapp -- /scripts/bootstrap.sh

  log "Creating tables for databases ..."
  safe_kubectl exec "${POSTGRES_POD_NAME-}" -n myapp -- /scripts/load_sql.sh

  log "Creating database secrets ..."
  kubectl_install_resource_from_file k8s/db-auth.yaml
}

kubectl_configure_coredns() {
  log "Kubectl: Configuring CoreDNS custom domain ..." "$ta_bold$fg_blue"

  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kubectl create configmap coredns-custom ... | kubectl apply -f -" "$fg_yellow"
  else
    safe_kubectl create configmap coredns-custom \
      --namespace kube-system \
      --from-literal="myapp.local.server=/myapp.local/${KUBEAPI_SERVER_IP-}" \
      --dry-run=client -o yaml | safe_kubectl apply -f -
  fi
}

kubectl_restart() {
  if [[ $# -lt 1 ]]; then
    script_exit "Missing required argument to kubectl_restart()!" 2
  fi

  log "Kubectl: Rolling restart of services ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    local namespace="myapp"
    local name="${service-}"

    if [[ -n "$(echo ${service-} | grep ':')" ]]; then
      name="$(echo ${service-} | cut -d ":" -f1)"
      namespace="$(echo ${service-} | cut -d ":" -f2)"
    fi

    log "Kubectl: Restarting deployment '${name-}' in namespace '${namespace-}' ..."

    if [[ -n ${dry_run-} ]]; then
      safe_kubectl rollout restart deployment "${name-}" -n "${namespace-}"
      continue
    fi
    # First install builds images before the Helm releases exist.
    if ! kubectl get deployment "${name-}" -n "${namespace-}" >/dev/null 2>&1; then
      log "Kubectl: deployment '${name-}' not found in '${namespace-}'; skipping restart" "$fg_yellow"
      continue
    fi
    safe_kubectl rollout restart deployment "${name-}" -n "${namespace-}"
  done
}

kubectl_restart_all_deployments() {
  if [[ $# -lt 1 ]]; then
    script_exit "Missing required argument to kubectl_restart_all_deployments()!" 2
  fi

  log "Kubectl: Restarting all deployments in namespace '${1-}' ..." "$ta_bold$fg_blue"
  safe_kubectl rollout restart deployment -n "${1-}"
}
