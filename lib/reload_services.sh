# lib/reload_services.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 17
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

reload_services() {
  log "Reloading all services ..." "$ta_bold$fg_blue"

  build_bff && \
    kubectl_configure_coredns && \
    helm_update_core_configs && \
    helm_update_backend_configs && \
    kubectl_restart_all_deployments myapp && \
    helm_update_service conductor guardian router && \
    helm_update_webapp_service
}

reload_services_init() {
  if [[ -n ${reload_backend_services-} ]]; then
    kubectl_restart_all_deployments default
  fi

  if [[ -n ${kubectl_restart-} ]]; then
    kubectl_restart ${kubectl_restart//,/ }
  fi

  if [[ -n ${reload_all-} ]]; then
    reload_services
  fi
}

reload_nginx_configs() {
  log "Nginx: Reloading nginx config ..." "$ta_bold$fg_blue"

  if check_files "${orig_cwd-}/external/default.conf.temp"; then
    rm -rf "${orig_cwd-}/external/default.conf" > /dev/null 2>&1

    check_binary sed && \
      sed -e 's/NODE_IP\b/'${KUBEAPI_SERVER_IP-}'/g' \
      "${orig_cwd-}/external/default.conf.temp" > "${orig_cwd-}/external/default.conf"
  fi
}

delete_all_pods_and_services() {
  log "Deleting all kubernetes PODS and SERVICES ..." "$ta_bold$fg_blue"

  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kubectl -n myapp delete po,svc --all; helm uninstall" "$fg_yellow"
    return 0
  fi

  local k8s=$(kubectl get pods -n myapp | wc -l)

  if [[ -z ${k8s-} ]]; then
    log "Kubectl: No kubernetes service running ..."
  else
    while [[ ! ${k8s-} -lt 4 ]]; do
      safe_kubectl -n myapp delete po,svc --all --force --grace-period=0 > /dev/null 2>&1
      helm list --short | xargs helm uninstall > /dev/null 2>&1
      k8s=$(kubectl get pods -n myapp 2> /dev/null | wc -l)
      sleep 1
    done

    log "All kubernetes pods and services deleted!"
  fi
}

cleanup_core_package_data() {
  local data_dir="${orig_cwd-}/data"

  if [[ ! -d "$data_dir" ]]; then
    verbose_print "No data directory to clean up."
    return 0
  fi

  # Guard: only delete if the path looks like a data cache
  # directory
  if [[ "$data_dir" != */data ]]; then
    script_exit "Refusing to delete unexpected path: $data_dir" 2
  fi

  log "Removing existing core package data at ${data_dir} ..." "$ta_bold$fg_blue"
  run_as_root rm -rf "$data_dir" > /dev/null 2>&1
}
