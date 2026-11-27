# lib/kind.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 11
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

start_env() {
  if is_kind; then
    log "Creating Kind cluster ..."
    if [[ -n ${dry_run-} ]]; then
      log "DRY-RUN: kind create cluster --config ${orig_cwd-}/kind-config.yaml" "$fg_yellow"
      log "Kind cluster ready (dry-run)"
      return 0
    fi
    # Kind requires absolute hostPath. The book's kind-config.yaml uses
    # ./services and ./scripts; rewrite them to this checkout.
    local kind_cfg
    kind_cfg="$(mktemp "${TMPDIR:-/tmp}/kind-config.XXXXXX.yaml")"
    sed -e "s|hostPath: \./services|hostPath: ${orig_cwd-}/services|" \
        -e "s|hostPath: \./scripts|hostPath: ${orig_cwd-}/scripts|" \
        "${orig_cwd-}/kind-config.yaml" > "$kind_cfg"
    kind create cluster --config "$kind_cfg"
    rm -f "$kind_cfg"
    log "Kind cluster ready"
  else
    script_exit "Operation not available on datacenter mode!" 2
  fi
}

stop_env() {
  if is_kind; then
    log "Stopping Kind cluster ..."
    if [[ -n ${dry_run-} ]]; then
      # Not specified as --dry-run in the book; skip the docker stop.
      log "DRY-RUN: docker stop kind-control-plane kind-worker kind-worker2" "$fg_yellow"
      return 0
    fi
    docker stop kind-control-plane kind-worker kind-worker2 2>/dev/null || true
  else
    script_exit "Operation not available on datacenter mode!" 2
  fi
}

delete_env() {
  if is_kind; then
    log "Deleting Kind cluster ..."
    if [[ -n ${dry_run-} ]]; then
      # Not specified as --dry-run in the book; skip cluster deletion.
      log "DRY-RUN: kind delete cluster" "$fg_yellow"
      return 0
    fi
    kind delete cluster
  else
    script_exit "Operation not available on datacenter mode!" 2
  fi
}
