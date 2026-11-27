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
    kubectl wait --for=condition=Ready nodes --all --timeout=180s
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

# Load a host image into every Kind node. `kind load docker-image` passes
# --all-platforms to ctr, which fails with "content digest not found" when
# Docker has only the current platform of a multi-arch image.
load_image_into_kind() {
  local img="${1-}"
  if [[ -z $img ]]; then
    script_exit "Missing required argument to load_image_into_kind()!" 2
  fi
  if [[ -n ${dry_run-} ]]; then
    log "DRY-RUN: kind load docker-image $img" "$fg_yellow"
    return 0
  fi

  local archive node attempt
  archive="$(mktemp "${TMPDIR:-/tmp}/kind-image.XXXXXX.tar")"
  docker save "$img" -o "$archive"

  for node in $(kind get nodes); do
    for attempt in 1 2 3; do
      if docker exec -i "$node" ctr --namespace=k8s.io images import - < "$archive"; then
        break
      fi
      if [[ $attempt -eq 3 ]]; then
        rm -f "$archive"
        script_exit "Failed to load image $img into Kind node $node" 1
      fi
      log "import of $img onto $node failed (attempt ${attempt}); retrying" "$fg_yellow"
      sleep 2
    done
  done

  rm -f "$archive"
  log "Loaded $img into Kind"
  return 0
}
