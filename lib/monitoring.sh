# lib/monitoring.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 20
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

helm_install_monitoring() {
  log "Monitoring: Installing Prometheus + Grafana stack ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade --install kube-prometheus-stack)
  cmd_args+=(--repo https://prometheus-community.github.io/helm-charts)
  cmd_args+=(--chart-version "${MONITORING_CHART_VERSION:-69.3.4}")
  cmd_args+=(--namespace monitoring)
  cmd_args+=(--create-namespace)
  cmd_args+=(--set "grafana.service.type=NodePort")
  cmd_args+=(--set "grafana.service.nodePort=${GRAFANA_NODE_PORT:-31300}")
  cmd_args+=(--set "prometheus.service.type=NodePort")
  cmd_args+=(--set "prometheus.service.nodePort=${PROMETHEUS_NODE_PORT:-31090}")
  cmd_args+=(--set "alertmanager.service.type=NodePort")
  cmd_args+=(--set "alertmanager.service.nodePort=${ALERTMANAGER_NODE_PORT:-31093}")
  cmd_args+=(--set "grafana.adminPassword=${GRAFANA_ADMIN_PASSWORD:-admin}")
  cmd_args+=(--wait)
  cmd_args+=(kube-prometheus-stack)

  safe_helm "${cmd_args[@]}"
}

monitoring_wait_ready() {
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: skipping monitoring_wait_ready" "$fg_yellow"
    return 0
  fi
  log "Monitoring: Waiting for Prometheus and Grafana to be ready ..."

  safe_kubectl wait deployment \
    kube-prometheus-stack-grafana \
    --namespace monitoring \
    --for=condition=Available \
    --timeout=300s

  safe_kubectl wait deployment \
    kube-prometheus-stack-kube-state-metrics \
    --namespace monitoring \
    --for=condition=Available \
    --timeout=300s

  # Prometheus itself is a StatefulSet
  safe_kubectl rollout status statefulset \
    prometheus-kube-prometheus-stack-prometheus \
    --namespace monitoring \
    --timeout=300s
}

monitoring_apply_servicemonitor() {
  # Default path is not printed in the book; skip when the file is absent
  # rather than inventing a ServiceMonitor manifest.
  local MANIFEST="${1:-${orig_cwd-}/k8s/servicemonitor.yaml}"

  if [[ ! -f ${MANIFEST} ]]; then
    log "Monitoring: no ServiceMonitor at ${MANIFEST}; skipping (not bundled)" "$fg_yellow"
    return 0
  fi

  log "Monitoring: Applying ServiceMonitor from ${MANIFEST} ..."

  check_files "${MANIFEST}" && \
    safe_kubectl apply -f "${MANIFEST}"
}

monitoring_port_forward() {
  local TARGET="${1:-grafana}"
  local LOCAL_PORT="${2:-3000}"

  case "${TARGET}" in
    grafana)
      local SVC="kube-prometheus-stack-grafana"
      local REMOTE_PORT=80
      ;;
    prometheus)
      local SVC="kube-prometheus-stack-prometheus"
      local REMOTE_PORT=9090
      ;;
    alertmanager)
      local SVC="kube-prometheus-stack-alertmanager"
      local REMOTE_PORT=9093
      ;;
    *)
      script_exit "monitoring_port_forward: unknown target '${TARGET}'" 2
      ;;
  esac

  log "Monitoring: Port-forwarding ${TARGET} to localhost:${LOCAL_PORT} ..."

  safe_kubectl port-forward \
    "svc/${SVC}" \
    "${LOCAL_PORT}:${REMOTE_PORT}" \
    --namespace monitoring &

  log "Monitoring: ${TARGET} accessible at http://localhost:${LOCAL_PORT}"
}

# Not printed as a complete function in the book. Ch18 says monitoring_init
# dispatches Prometheus/Grafana operations following the same pattern.
monitoring_init() {
  if [[ -n ${install_monitoring-} ]]; then
    helm_install_monitoring
    monitoring_wait_ready
    monitoring_apply_servicemonitor
  fi
  if [[ -n ${monitoring_fwd-} ]]; then
    monitoring_port_forward
  fi
}
