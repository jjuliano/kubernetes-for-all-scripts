# lib/argocd.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 19
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

safe_argocd() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to safe_argocd()!' 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: argocd $*" "$fg_yellow"
    return 0
  fi


  check_binary argocd && \
    argocd "${@-}"
}

helm_install_argocd() {
  log "ArgoCD: Installing controller ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade --install argocd)
  cmd_args+=(--repo https://argoproj.github.io/argo-helm)
  cmd_args+=(--chart-version "${ARGOCD_CHART_VERSION:-7.8.0}")
  cmd_args+=(--namespace argocd)
  cmd_args+=(--create-namespace)
  cmd_args+=(--set "server.service.type=NodePort")
  cmd_args+=(--set "server.service.nodePortHttp=${ARGOCD_NODE_PORT:-30080}")
  cmd_args+=(--wait)
  cmd_args+=(argo-cd)

  safe_helm "${cmd_args[@]}"
}

argocd_wait_ready() {
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: skipping argocd_wait_ready" "$fg_yellow"
    return 0
  fi
  log "ArgoCD: Waiting for server to be ready ..."

  safe_kubectl wait deployment argocd-server \
    --namespace argocd \
    --for=condition=Available \
    --timeout=300s
}

argocd_login() {
  log "ArgoCD: Logging in ..."

  local SERVER="${ARGOCD_SERVER:-localhost:${ARGOCD_NODE_PORT:-30080}}"
  local PASSWORD
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kubectl get secret argocd-initial-admin-secret ... | base64 --decode" "$fg_yellow"
    PASSWORD="dry-run"
  else
    PASSWORD="$(safe_kubectl get secret argocd-initial-admin-secret \
      --namespace argocd \
      --output jsonpath='{.data.password}' \
      | base64 --decode)"
  fi

  safe_argocd login "${SERVER}" \
    --username admin \
    --password "${PASSWORD}" \
    --insecure
}

argocd_create_app() {
  if [[ $# -lt 3 ]]; then
    script_exit 'Usage: argocd_create_app <name> <repo-url> <path>' 2
  fi

  local APP_NAME="${1}"
  local REPO_URL="${2}"
  local APP_PATH="${3}"
  local DEST_NAMESPACE="${4:-myapp}"
  local TARGET_REVISION="${5:-HEAD}"

  log "ArgoCD: Registering application '${APP_NAME}' from ${REPO_URL}/${APP_PATH} ..."

  local cmd_args=()
  cmd_args+=(app create "${APP_NAME}")
  cmd_args+=(--repo "${REPO_URL}")
  cmd_args+=(--path "${APP_PATH}")
  cmd_args+=(--dest-server https://kubernetes.default.svc)
  cmd_args+=(--dest-namespace "${DEST_NAMESPACE}")
  cmd_args+=(--revision "${TARGET_REVISION}")
  cmd_args+=(--sync-policy automated)
  cmd_args+=(--auto-prune)
  cmd_args+=(--self-heal)
  cmd_args+=(--upsert)

  safe_argocd "${cmd_args[@]}"
}

argocd_sync() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Usage: argocd_sync <app-name>' 2
  fi

  local APP_NAME="${1}"

  log "ArgoCD: Syncing application '${APP_NAME}' ..."

  safe_argocd app sync "${APP_NAME}" --timeout 300
}

argocd_wait_healthy() {
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: skipping argocd_wait_healthy" "$fg_yellow"
    return 0
  fi
  if [[ $# -lt 1 ]]; then
    script_exit 'Usage: argocd_wait_healthy <app-name>' 2
  fi

  local APP_NAME="${1}"

  log "ArgoCD: Waiting for '${APP_NAME}' to reach Healthy/Synced state ..."

  safe_argocd app wait "${APP_NAME}" \
    --health \
    --sync \
    --timeout 300
}

argocd_delete_app() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Usage: argocd_delete_app <app-name>' 2
  fi

  local APP_NAME="${1}"

  log "ArgoCD: Deleting application '${APP_NAME}' ..."

  safe_argocd app delete "${APP_NAME}" \
    --cascade \
    --yes
}

# Not printed as a complete function in the book. Ch18 says argocd_init
# dispatches GitOps operations the same way as the other *_init functions.
argocd_init() {
  if [[ -n ${install_argocd-} ]]; then
    helm_install_argocd
    argocd_wait_ready
    argocd_login
  fi
  if [[ -n ${argocd_app-} ]]; then
    # Comma-separated: name,repo-url,path[,namespace][,revision]
    # shellcheck disable=SC2086
    argocd_create_app ${argocd_app//,/ }
    local app_name="${argocd_app%%,*}"
    argocd_sync "$app_name"
    argocd_wait_healthy "$app_name"
  fi
  if [[ -n ${delete_argocd_app-} ]]; then
    argocd_delete_app ${delete_argocd_app//,/ }
  fi
}
