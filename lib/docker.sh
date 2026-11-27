# lib/docker.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 12
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

# Not specified in the book. --dry-run logs the command and skips execution
# so the script can be inspected without Docker, kubectl, Helm, or a cluster.
run_cmd() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to run_cmd()!' 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: $*" "$fg_yellow"
    return 0
  fi
  "$@"
}

safe_docker() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to safe_docker()!' 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: docker $*" "$fg_yellow"
    return 0
  fi


  if check_binary docker; then
    docker "${@-}"
  fi
}

safe_docker_build() {
  local build_args=()
  [[ -n ${clean_build-} ]] && build_args+=(--no-cache)

  if ! is_kind; then
    build_args+=(--network "${DOCKER_NETWORK_MODE-}")
  fi

  safe_docker build "${build_args[@]}" "${@-}"
}

safe_docker_run() {
  if is_kind; then
    # The book bind-mounts /services and /scripts (paths inside the Kind
    # node). On the host, mount this checkout at those same container paths.
    check_directories "$(get_repos_dir)/" "$(get_repos_dir)/webapp/" \
      "${orig_cwd-}/scripts/" && \
      check_files "${orig_cwd-}/scripts/install_deps.sh" && \
      safe_docker run --rm \
      -v "$(get_repos_dir)/":/go/src/github.com/myapp-dev/ \
      -v "${orig_cwd-}/data/go/":/go/ \
      -v "${orig_cwd-}/scripts/":/scripts/ \
      -v "$(get_repos_dir)/webapp/":/webapp/ \
      -v /etc/hosts:/hosts \
      -v "${orig_cwd-}/scripts/install_deps.sh":/install_deps.sh \
      -e "GITHUB_TOKEN=${GITHUB_TOKEN-}" \
      -e "REPOS_DIR=/go/src/github.com/myapp-dev" "${@-}"
  else
    check_directories "$(get_repos_dir)/" "${orig_cwd-}/services/webapp/" \
      "${orig_cwd-}/scripts/" && \
      check_files "${orig_cwd-}/scripts/install_deps.sh" && \
      safe_docker run --network "${DOCKER_NETWORK_MODE-}" --rm \
      -v "$(get_repos_dir)/":/go/src/github.com/myapp-dev/ \
      -v "${orig_cwd-}/data/go/":/go/ \
      -v "${orig_cwd-}/scripts/":/scripts/ \
      -v "${orig_cwd-}/services/webapp/":/webapp/ \
      -v /etc/hosts:/hosts \
      -v "${orig_cwd-}/scripts/install_deps.sh":/install_deps.sh \
      -e "GITHUB_TOKEN=${GITHUB_TOKEN-}" \
      -e "REPOS_DIR=/go/src/github.com/myapp-dev" "${@-}"
  fi
}

safe_docker_tag() {
  safe_docker tag "${@-}"
}

safe_docker_push() {
  if is_kind; then
    # Load directly into Kind nodes — no registry needed
    load_image_into_kind "${1-}"
  else
    safe_docker push "${@-}"
  fi
}

safe_docker_compose() {
  check_files "${orig_cwd-}/external/docker-compose.yaml" && \
    run_cmd docker compose -f "${orig_cwd-}/external/docker-compose.yaml" "${@-}"
}

docker_compose_up() {
  local expected=4  # nginx + kafka (3 KRaft nodes) = 4 containers

  log "Docker Compose: starting up kafka and nginx ..." "$ta_bold$fg_blue"

  safe_docker_compose up -d

  if [[ -n ${dry_run-} ]]; then
    return 0
  fi

  local status=""
  local waited=0
  local timeout="${COMPOSE_UP_TIMEOUT:-180}"
  while [[ "${status-}" -ne $expected ]]; do
    if (( waited >= timeout )); then
      script_exit "Docker Compose: timed out waiting for ${expected} external_ containers" 1
    fi
    status=$(docker ps | grep -i external_ | wc -l)
    sleep 1
    waited=$((waited + 1))
  done

  log "Docker Compose: start up of docker machines complete ..."
}


# The book (Ch12) describes docker_compose_down as the mirror of
# docker_compose_up but does not print the function body.
docker_compose_down() {
  log "Docker Compose: shutting down kafka and nginx ..." "$ta_bold$fg_blue"

  safe_docker_compose down

  if [[ -n ${dry_run-} ]]; then
    return 0
  fi

  local status="1"
  local waited=0
  local timeout="${COMPOSE_DOWN_TIMEOUT:-120}"
  while [[ "${status-}" -ne 0 ]]; do
    if (( waited >= timeout )); then
      script_exit "Docker Compose: timed out waiting for external_ containers to stop" 1
    fi
    status=$(docker ps | grep -i external_ | wc -l)
    sleep 1
    waited=$((waited + 1))
  done

  log "Docker Compose: shutdown of docker machines complete ..."
}

docker_cleanup() {
  log "Docker: Performing docker cleanup ..." "$ta_bold$fg_blue"

  log "Docker: Pruning stopped containers, unused images, and unused volumes ..."

  safe_docker container prune --force
  safe_docker image prune --all --force
  safe_docker volume prune --force
}
