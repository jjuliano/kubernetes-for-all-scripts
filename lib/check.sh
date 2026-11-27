# lib/check.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 15
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

check_registry() {
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kubectl get service registry-service -n myapp" "$fg_yellow"
    install_kubernetes_service registry
    configure_registry
    return 0
  fi

  if ! kubectl get service registry-service -n myapp >/dev/null 2>&1; then
    install_kubernetes_service registry && \
      configure_registry
  fi

  return 0
}
