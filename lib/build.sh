# lib/build.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 15
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

build_service() {
  if [[ $# -lt 1 ]]; then
    script_exit "Missing required argument to build_service()!" 2
  fi

  local SERVICE="${1-}"
  local SERVICE_DIR="${2-}"

  if check_registry; then
    local REGISTRY_IP
    if [[ -n ${dry_run-} ]]; then
      log "DRY-RUN: kubectl get service registry-service -n myapp" "$fg_yellow"
      REGISTRY_IP="127.0.0.1"
    else
      REGISTRY_IP="$(kubectl get service registry-service \
        -n myapp -o jsonpath="{.spec.clusterIP}")"
    fi
    local TAG="${REGISTRY_IP}:5000/myapp/${SERVICE}:latest"

    if check_arguments REGISTRY_IP TAG SERVICE SERVICE_DIR; then
      if check_directories "${SERVICE_DIR-}"; then
        log "Docker: Building ${SERVICE}"

        safe_docker_build -t "${TAG-}" \
          --build-arg="GITHUB_TOKEN=${GITHUB_TOKEN-}" \
          "${SERVICE_DIR-}"
        safe_docker_tag "${TAG-}" \
          "registry-service:5000/myapp/${SERVICE-}:latest"
        safe_docker_tag "${TAG-}" \
          "registry-service:5000/myapp/${SERVICE-}:built"
        safe_docker_push "${TAG-}"
        # Helm charts pull by the in-cluster DNS name (Chapter 15).
        if is_kind; then
          load_image_into_kind "registry-service:5000/myapp/${SERVICE-}:latest"
        fi

        log "Docker: Service ${SERVICE-} successfully built ..."
      fi
    fi
  fi
}

build_backend_services() {
  log "Docker: Building core services ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    build_service "${service-}" "$(get_repos_dir)/${service-}"
    kubectl_restart "${service-}":myapp
  done
}

build_runtime_components() {
  log "Docker: Building runtime components ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    build_service "${service-}" "$(get_repos_dir)/runtime-components/${service-}"
  done
}

build_runtime_modules() {
  log "Docker: Building runtime modules ..." "$ta_bold$fg_blue"

  for service in "${@-}"; do
    build_service "${service-}" "$(get_repos_dir)/runtime-modules/${service-}"
  done
}

build_images_init() {
  if [[ -n ${build_images-} ]]; then
    build_router
  fi

  if [[ -n ${build_project_containers-} ]]; then
    build_backend_services backend guardian
    build_runtime_components seeder logger registry pds
    build_runtime_modules scanner cache frontier bridge
  fi

  if [[ -n ${build_backend_services-} ]]; then
    if [[ -n ${build_project_containers-} ]]; then
      script_exit "Cannot be combined with build project containers!" 2
    fi
    build_backend_services ${build_backend_services//,/ }
  fi

  if [[ -n ${build_services-} ]]; then
    if [[ -n ${build_project_containers-} ]]; then
      script_exit "Cannot be combined with build project containers!" 2
    fi

    local actions=""

    [[ -n ${build_guardian-} ]] &&
      actions="${actions-},build_backend_services-guardian"
    [[ -n ${build_seeder-} ]] && \
      actions="${actions-},build_runtime_components-seeder"
    [[ -n ${build_logger-} ]] && \
      actions="${actions-},build_runtime_components-logger"

    for action_id in ${actions#,}; do
      local action=${action_id//-/ }
      local name=$(echo ${action} | cut -d " " -f2)
      ${action}
    done
  fi
}

build_router() {
  log "Docker: Building Router ..." "$ta_bold$fg_blue"

  if check_directories "$(get_repos_dir)/router"; then
    safe_docker_build -t myapplocal/router "$(get_repos_dir)/router"
    safe_docker_tag myapplocal/router "registry-service:5000/myapp/router:latest"
    # Kind cannot pull myapplocal/router unless it is loaded (Chapter 11).
    safe_docker_push myapplocal/router
    kubectl_restart router:myapp
    helm_install_service router:myapp
    kubectl_restart router:myapp
  fi
}

# The book builds the frontend with safe_docker_run (build_bff) but does not
# print a container image step. Package the result so helm_install_webapp_service
# has an image to deploy.
build_webapp_image() {
  log "Docker: Building webapp image ..." "$ta_bold$fg_blue"
  local webapp_dir
  webapp_dir="$(get_repos_dir)/webapp"
  if check_directories "$webapp_dir"; then
    # dist/ is produced by build_bff; fall back to public/ if needed.
    if [[ ! -d "${webapp_dir}/dist" && -d "${webapp_dir}/public" ]]; then
      mkdir -p "${webapp_dir}/dist"
      cp -a "${webapp_dir}/public/." "${webapp_dir}/dist/"
    fi
    build_service webapp "$webapp_dir"
  fi
}

build_bff() {
  log "Docker: Building BFF ..." "$ta_bold$fg_blue"

  check_directories "$(get_repos_dir)/webapp/" && \
    safe_docker_run "node:${NODE_VERSION:-20}" /bin/sh -c \
      "cd /webapp && npm install && npm run build && sed -i \"s/API_URL_PLACEHOLDER/http:\/\/${KUBEAPI_SERVER_IP-}/g\" dist/config.js"
}
