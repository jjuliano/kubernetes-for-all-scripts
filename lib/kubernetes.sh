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
  if [[ -f $helper ]]; then
    if [[ -n ${dry_run-} ]]; then
      log "DRY-RUN: bash $helper" "$fg_yellow"
      return 0
    fi
    # shellcheck disable=SC1090
    bash "$helper"
  else
    # Minimal fallback if the helper script is absent.
    local images=(
      "golang:${GO_VERSION:-1.22}"
      "node:${NODE_VERSION:-20}"
      "postgres:16"
      "registry:2"
      "nginx:latest"
    )
    local img
    for img in "${images[@]}"; do
      if [[ -n ${dry_run-} ]]; then
        log "DRY-RUN: docker pull $img" "$fg_yellow"
      else
        safe_docker pull "$img"
      fi
    done
  fi
}

get_kube_params() {
  log "Kubectl: Getting Kubernetes server IP params ..." "$ta_bold$fg_blue"

  if is_kind; then
    export KUBEAPI_SERVER_IP="$(kubectl get node kind-control-plane \
      -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
  else
    if check_binary ip; then
      export KUBEAPI_SERVER_IP="$(ip -4 addr show eth0 \
        | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
    fi
  fi

  if check_binary kubectl; then
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
  pull_images
  build_router

  log "Kubectl: Installing the Myapp namespace ..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/myapp-namespace.yaml

  log "Kubectl: Installing registry resource..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/registry.yaml

  build_backend_services backend guardian
  build_runtime_components seeder logger registry pds
  build_runtime_modules scanner cache frontier bridge

  kubectl_install_database

  log "This will take a couple of minutes..." "$ta_blink"
  install_deps all

  build_bff

  log "Creating k8s privileged user ..." "$ta_bold$fg_blue"
  kubectl_install_resource_from_file k8s/service-account.yaml

  docker_compose_up

  kubectl_configure_coredns

  if is_kind; then
    log "Installing volumes ..." "$ta_bold$fg_blue"
    kubectl_install_resource_from_file k8s/disks/local-volume.yaml
    log "Installing volume claims ..." "$ta_bold$fg_blue"
    kubectl_install_resource_from_file k8s/disks/local-volume-claim.yaml
  fi

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
