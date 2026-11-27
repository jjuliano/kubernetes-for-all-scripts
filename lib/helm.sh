# lib/helm.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 14
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

safe_helm() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to safe_helm()!' 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: helm $*" "$fg_yellow"
    return 0
  fi


  check_binary helm && \
    check_directories "${orig_cwd-}/k8s/" && \
    if helm "${@-}"; then
      return 0
    else
      log "Helm command failed; dumping cluster state" "$fg_red"
      kubectl get pods,deploy,svc -A || true
      kubectl describe pods -n myapp || true
      kubectl get events -A --sort-by=.lastTimestamp | tail -50 || true
      if is_kind && command -v kind >/dev/null 2>&1; then
        for _node in $(kind get nodes 2>/dev/null); do
          log "Images on ${_node}:"
          docker exec "$_node" ctr --namespace=k8s.io images ls || true
        done
      fi
      return 1
    fi
}

helm_install_service() {
  log "Helm: Installing services ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    local name="$(echo ${service-} | cut -d ":" -f1)"
    local namespace="myapp"
    [[ -n "$(echo ${service-} | grep ':')" ]] \
      && namespace="$(echo ${service-} | cut -d ":" -f2)"

    log "Helm: Installing '${name-}' in namespace '${namespace-}' ..."

    local cmd_args=()
    cmd_args+=(upgrade --install "$name")

    [[ -f "${orig_cwd-}/k8s/${name-}-values.yaml" ]] \
      && cmd_args+=(--values "${orig_cwd-}/k8s/${name-}-values.yaml")

    cmd_args+=(--set "kube_token=${TOKEN-}")
    cmd_args+=(--set "kubeapi=https://${KUBEAPI_SERVER_IP-}:6443/")
    cmd_args+=(--namespace "$namespace")
    cmd_args+=(--wait)

    if [[ -d "${orig_cwd-}/k8s/${name-}" ]]; then
      cmd_args+=("${orig_cwd-}/k8s/${name-}")
    else
      # Values files such as conductor-values.yaml override the generic
      # core-service chart (Chapter 14).
      cmd_args+=("${orig_cwd-}/k8s/core-service")
    fi

    safe_helm "${cmd_args[@]}"
  done
}

helm_install_core_service() {
  log "Helm: Installing core services ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    log "Helm: Installing core service ${service-} ..."

    local cmd_args=()
    cmd_args+=(upgrade --install "$service")
    cmd_args+=(--values "${orig_cwd-}/k8s/${service-}-values.yaml")
    cmd_args+=(--namespace myapp)
    cmd_args+=(--wait)
    cmd_args+=("${orig_cwd-}/k8s/core-service")

    check_files "${orig_cwd-}/k8s/${service-}-values.yaml" && \
      check_directories "${orig_cwd-}/k8s/core-service" && \
      safe_helm "${cmd_args[@]}"
  done
}

helm_install_core_configs() {
  log "Helm: Installing core configs ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade --install core-configs)
  cmd_args+=(--set "map.token=${TOKEN-}")
  cmd_args+=(--set "map.k8s_api_url=https://${KUBEAPI_SERVER_IP-}:6443/")
  cmd_args+=(--set "map.guardian_url=http://${KUBEAPI_SERVER_IP-}:32001/")
  cmd_args+=(--set "map.kafka_brokers=${KUBEAPI_SERVER_IP-}:19092")
  cmd_args+=(--namespace myapp)
  cmd_args+=("${orig_cwd-}/k8s/development-core-configs")

  check_directories "${orig_cwd-}/k8s/development-core-configs" && \
    safe_helm "${cmd_args[@]}"
}

helm_install_backend_configs() {
  log "Helm: Installing backend configs ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade --install backend-configs)
  cmd_args+=(--set "map.token=${TOKEN-}")
  cmd_args+=(--set "map.k8s_api_url=https://${KUBEAPI_SERVER_IP-}:6443/")
  cmd_args+=(--namespace myapp)
  cmd_args+=("${orig_cwd-}/k8s/development-backend-configs")

  check_directories "${orig_cwd-}/k8s/development-backend-configs" && \
    safe_helm "${cmd_args[@]}"
}

helm_update_core_configs() {
  log "Helm: Reloading core configs ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade core-configs)
  cmd_args+=(--set "map.token=${TOKEN-}")
  cmd_args+=(--set "map.k8s_api_url=https://${KUBEAPI_SERVER_IP-}:6443/")
  cmd_args+=(--set "map.guardian_url=http://${KUBEAPI_SERVER_IP-}:32001/")
  cmd_args+=(--set "map.kafka_brokers=${KUBEAPI_SERVER_IP-}:19092")
  cmd_args+=(--namespace myapp)
  cmd_args+=("${orig_cwd-}/k8s/development-core-configs")

  check_directories "${orig_cwd-}/k8s/development-core-configs" && \
    safe_helm "${cmd_args[@]}"
}

helm_install_traefik_service() {
  log "Helm: Installing Traefik ingress controller ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade --install traefik)
  cmd_args+=(--namespace kube-system)
  cmd_args+=(--wait)
  cmd_args+=("${orig_cwd-}/k8s/traefik")

  check_directories "${orig_cwd-}/k8s/traefik" && \
    safe_helm "${cmd_args[@]}"
}

helm_install_volume() {
  log "Helm: Installing volume ..." "$ta_bold$fg_blue"

  check_directories "${orig_cwd-}/k8s/local-env-volumes" && \
    safe_helm upgrade --install local-env-volumes \
    --namespace myapp "${orig_cwd-}/k8s/local-env-volumes"
}

helm_install_webapp_service() {
  log "Helm: Installing webapp ..." "$ta_bold$fg_blue"

  check_directories "${orig_cwd-}/k8s/webapp" && \
    safe_helm upgrade --install webapp \
    --set "kubeapi=https://${KUBEAPI_SERVER_IP-}:6443/" \
    --namespace myapp --wait "${orig_cwd-}/k8s/webapp"
}

# The book (Ch17) calls these update helpers but does not print them.
# They follow helm_update_core_configs (Ch14): helm upgrade without --install.
helm_update_backend_configs() {
  log "Helm: Reloading backend configs ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade backend-configs)
  cmd_args+=(--set "map.token=${TOKEN-}")
  cmd_args+=(--set "map.k8s_api_url=https://${KUBEAPI_SERVER_IP-}:6443/")
  cmd_args+=(--namespace myapp)
  cmd_args+=("${orig_cwd-}/k8s/development-backend-configs")

  check_directories "${orig_cwd-}/k8s/development-backend-configs" && \
    safe_helm "${cmd_args[@]}"
}

helm_update_service() {
  log "Helm: Updating services ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    local name="$(echo ${service-} | cut -d ":" -f1)"
    local namespace="myapp"
    [[ -n "$(echo ${service-} | grep ':')" ]] \
      && namespace="$(echo ${service-} | cut -d ":" -f2)"

    log "Helm: Updating '${name-}' in namespace '${namespace-}' ..."

    local cmd_args=()
    cmd_args+=(upgrade "$name")

    [[ -f "${orig_cwd-}/k8s/${name-}-values.yaml" ]] \
      && cmd_args+=(--values "${orig_cwd-}/k8s/${name-}-values.yaml")

    cmd_args+=(--set "kube_token=${TOKEN-}")
    cmd_args+=(--set "kubeapi=https://${KUBEAPI_SERVER_IP-}:6443/")
    cmd_args+=(--namespace "$namespace")
    cmd_args+=(--wait)

    if [[ -d "${orig_cwd-}/k8s/${name-}" ]]; then
      cmd_args+=("${orig_cwd-}/k8s/${name-}")
    else
      cmd_args+=("${orig_cwd-}/k8s/core-service")
    fi

    safe_helm "${cmd_args[@]}"
  done
}

helm_update_webapp_service() {
  log "Helm: Updating webapp ..." "$ta_bold$fg_blue"

  check_directories "${orig_cwd-}/k8s/webapp" && \
    safe_helm upgrade webapp \
    --set "kubeapi=https://${KUBEAPI_SERVER_IP-}:6443/" \
    --namespace myapp --wait "${orig_cwd-}/k8s/webapp"
}
