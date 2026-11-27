# lib/kubernetes.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 16
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

# The book (Ch16) says pull_images runs k8s/docker_images.sh, a script of
# docker pull commands for golang, node, postgres, registry:2, nginx, and Kafka.
pull_images() {
  log "Docker: Pulling base images ..." "$ta_bold$fg_blue"
  local helper="${orig_cwd-}/k8s/docker_images.sh"
  local images=(
    "golang:${GO_VERSION:-1.22}"
    "python:3.12-alpine"
    "node:${NODE_VERSION:-20}"
    "postgres:16"
    "registry:2"
    "nginx:latest"
    "${KAFKA_IMAGE:-apache/kafka:3.9.1}"
    "traefik:v3.3"
  )
  if [[ -f $helper ]]; then
    if [[ -n ${dry_run-} ]]; then
      log "DRY-RUN: bash $helper" "$fg_yellow"
    else
      # shellcheck disable=SC1090
      bash "$helper"
    fi
  else
    local img
    for img in "${images[@]}"; do
      if [[ -n ${dry_run-} ]]; then
        log "DRY-RUN: docker pull $img" "$fg_yellow"
      else
        safe_docker pull "$img"
      fi
    done
  fi

  # Kind nodes do not see host images until they are loaded (Chapter 11).
  if is_kind; then
    local img
    for img in "${images[@]}"; do
      run_cmd kind load docker-image "$img"
    done
  fi
}

get_kube_params() {
  log "Kubectl: Getting Kubernetes server IP params ..." "$ta_bold$fg_blue"

  if is_kind; then
    if kubectl get node kind-control-plane >/dev/null 2>&1; then
      export KUBEAPI_SERVER_IP="$(kubectl get node kind-control-plane \
        -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
    else
      log "Kind cluster is not ready yet; kube params will be refreshed later" "$fg_yellow"
      return 0
    fi
  else
    if check_binary ip; then
      export KUBEAPI_SERVER_IP="$(ip -4 addr show eth0 \
        | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
    fi
  fi

  if check_binary kubectl && kubectl get sa admin-user -n kube-system >/dev/null 2>&1; then
    export TOKEN="$(kubectl create token admin-user -n kube-system --duration=24h)"
  fi
}

configure_registry() {
  log "Docker: Configuring registry access ..."

  local REGISTRY_IP
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kubectl get service registry-service -n myapp" "$fg_yellow"
    REGISTRY_IP="127.0.0.1"
  else
    REGISTRY_IP=$(kubectl get service registry-service -n myapp -o \
      jsonpath='{.spec.clusterIP}')
  fi

  check_arguments REGISTRY_IP

  if is_kind; then
    log "Kind mode: images are loaded via 'kind load docker-image' — no
      registry configuration needed"
  else
    log "Datacenter mode: registry available at ${REGISTRY_IP}:5000"
  fi
}

install_kubernetes_service() {
  log "Kubectl: Installing kubernetes service ${1-} ..." "$ta_bold$fg_blue"

  kubectl_install_resource_from_file "k8s/${1-}.yaml"
}

setup_k8s() {
  # `--kind --install` should bring the cluster up. The book lists
  # start_env as a separate flag; call it here when no cluster exists
  # so a single command provisions a working local environment.
  if is_kind; then
    if [[ -n ${dry_run-} ]] || ! kind get clusters 2>/dev/null | grep -qx kind; then
      start_env
    fi
  fi

  pull_images

  log "Kubectl: Installing the Myapp namespace ..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/myapp-namespace.yaml

  # The book's printed postgres.yaml mounts local-volume-claim and
  # references the db-auth secret. Apply both before the database so
  # the postgres pod can start.
  if is_kind; then
    log "Installing volumes ..." "$ta_bold$fg_blue"
    kubectl_install_resource_from_file k8s/disks/local-volume.yaml
    log "Installing volume claims ..." "$ta_bold$fg_blue"
    kubectl_install_resource_from_file k8s/disks/local-volume-claim.yaml
  fi
  log "Kubectl: Installing database credentials ..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/db-auth.yaml

  log "Kubectl: Installing registry resource..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/registry.yaml
  configure_registry

  build_router
  build_backend_services backend guardian
  build_runtime_components seeder logger registry pds
  build_runtime_modules scanner cache frontier bridge
  # Core services are installed from the core-service chart and need images too.
  for _svc in keymaster datastore migrator herald myapp-auth; do
    build_service "$_svc" "$(get_repos_dir)/${_svc}"
  done

  kubectl_install_database

  log "This will take a couple of minutes..." "$ta_blink"
  install_deps all

  build_bff
  build_webapp_image

  log "Creating k8s privileged user ..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/service-account.yaml
  # TOKEN is consumed by the config charts; refresh after the SA exists.
  if [[ -z ${dry_run-} ]]; then
    get_kube_params
  fi

  reload_nginx_configs
  docker_compose_up

  kubectl_configure_coredns

  helm_install_volume

  helm_install_core_configs
  helm_install_backend_configs

  helm_install_service conductor guardian router
  helm_install_core_service keymaster datastore migrator herald myapp-auth

  helm_install_traefik_service
  helm_install_webapp_service

  kubectl_install_resource_from_file k8s/namespace-services.yaml

  configure_registry
}
