# lib/otel.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 21
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

safe_otel() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to safe_otel()!' 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: otel $*" "$fg_yellow"
    return 0
  fi


  check_binary kubectl && \
    kubectl "${@-}"
}

helm_install_otel_operator() {
  log "OTel: Installing OpenTelemetry Operator ..." "$ta_bold$fg_blue"

  local cmd_args=()
  cmd_args+=(upgrade --install opentelemetry-operator)
  cmd_args+=(--repo https://open-telemetry.github.io/opentelemetry-helm-charts)
  cmd_args+=(--chart-version "${OTEL_OPERATOR_CHART_VERSION:-0.76.1}")
  cmd_args+=(--namespace opentelemetry-operator-system)
  cmd_args+=(--create-namespace)
  cmd_args+=(--set "admissionWebhooks.certManager.enabled=false")
  cmd_args+=(--set "admissionWebhooks.autoGenerateCert.enabled=true")
  cmd_args+=(--wait)
  cmd_args+=(opentelemetry-operator)

  safe_helm "${cmd_args[@]}"
}

otel_wait_ready() {
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: skipping otel_wait_ready" "$fg_yellow"
    return 0
  fi
  log "OTel: Waiting for operator to be ready ..."

  safe_kubectl wait deployment \
    opentelemetry-operator-controller-manager \
    --namespace opentelemetry-operator-system \
    --for=condition=Available \
    --timeout=300s
}

otel_apply_collector() {
  # Default path is not printed in the book; skip when the file is absent
  # rather than inventing an OpenTelemetryCollector manifest.
  local MANIFEST="${1:-${orig_cwd-}/k8s/otel-collector.yaml}"

  if [[ ! -f ${MANIFEST} ]]; then
    log "OTel: no OpenTelemetryCollector at ${MANIFEST}; skipping (not bundled)" "$fg_yellow"
    return 0
  fi

  log "OTel: Applying OpenTelemetryCollector from ${MANIFEST} ..."

  check_files "${MANIFEST}" && \
    safe_kubectl apply -f "${MANIFEST}"
}

# Not printed as a complete function in the book. Ch18 says otel_init
# dispatches OpenTelemetry operations following the same pattern.
otel_init() {
  if [[ -n ${install_otel-} ]]; then
    helm_install_otel_operator
    otel_wait_ready
    otel_apply_collector
  fi
}
