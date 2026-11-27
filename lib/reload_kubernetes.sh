# lib/reload_kubernetes.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 17
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

reload_kubernetes() {
  reload_all_kubernetes
  exit 0
}

reload_all_kubernetes() {
  log "Reloading kubernetes service ..." "$ta_bold$fg_blue"

  systemctl_reload_kubernetes
  delete_all_pods_and_services
  docker_compose_down

  pull_images
  build_router
  helm_install_service router

  reload_nginx_configs
  docker_compose_up

  for service in myapp-namespace namespace-services db-auth postgres registry service-account; do
    log "Kubectl: Installing kubernetes service ${service-} ..." "$ta_bold$fg_blue"
    kubectl_install_resource_from_file "k8s/${service-}.yaml"
  done

  configure_registry
  cleanup_core_package_data
  install_deps all

  build_backend_services backend guardian
  build_runtime_components seeder logger registry pds
  build_runtime_modules scanner cache frontier bridge
  build_router

  helm_install_volume
  helm_install_core_configs
  helm_install_backend_configs
  helm_install_service conductor guardian router
  helm_install_core_service keymaster datastore migrator herald myapp-auth
  helm_install_traefik_service
  helm_install_webapp_service
  reload_services
  kubectl_restart_all_deployments myapp
  docker_cleanup
}

reload_kubernetes_init() {
  # parse_params (Ch10) sets reload_all_kubernetes; the book's init
  # checks reload_kubernetes. Honour both so -rk works.
  if [[ -n ${reload_kubernetes-} || -n ${reload_all_kubernetes-} ]]; then
    reload_kubernetes
  fi
}

systemctl_reload_kubernetes() {
  log "Systemctl: reloading kubernetes systemd service ..." "$ta_bold$fg_blue"

  if is_kind; then
    log "Kind mode: kubelet runs inside the Kind node; skipping host systemctl" "$fg_yellow"
    return 0
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: systemctl restart kubelet.service" "$fg_yellow"
    return 0
  fi
  check_binary systemctl && run_as_root systemctl restart kubelet.service

  if [[ -n ${dry_run-} ]]; then
    return 0
  fi

  local status=""

  while [[ "${status-}" != 'active' ]]; do
    status=$(systemctl is-active kubelet)
    sleep 1
  done

  log "Systemctl: reloading kubernetes systemd service complete ..."
}
