#!/usr/bin/env bash
# datacenter.sh — main entry point for Kubernetes for All
# From Kubernetes for All by Joel Bryan Juliano
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
# set -o xtrace

# Book sources "$PWD"/lib/*.sh. Also honour the script's own directory
# so --help and --dry-run work when invoked from another working directory.
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in "$_script_dir"/lib/*.sh; do
  [[ -f "$lib" ]] && source "$lib"
done

script_exit() {
  if [[ $# -eq 1 ]]; then
    printf '%s\n' "$1"
    exit 0
  fi

  if [[ ${2-} =~ ^[0-9]+$ ]]; then
    printf '%b\n' "$1"

    if [[ $2 -ne 0 ]]; then
      script_err_handler "$2"
    else
      exit 0
    fi
  fi

  script_exit 'Missing required argument to script_exit()!' 2
}

script_err_handler() {
  local exit_code=1

  trap - ERR

  set +o errexit
  set +o pipefail

  if [[ ${1-} =~ ^[0-9]+$ ]]; then
    exit_code=$1
  fi

  if [[ -n ${cron-} ]]; then
    if [[ -n ${script_output-} ]]; then
      exec 1>&3 2>&4
    fi

    printf '***** Abnormal termination of script *****\n'
    printf 'Script Path:            %s\n' "$script_path"
    printf 'Script Parameters:      %s\n' "$script_params"
    printf 'Script Exit Code:       %s\n' "$exit_code"

    if [[ -n ${script_output-} ]]; then
      printf 'Script Output:\n\n%s' "$(cat "$script_output")"
    else
      printf 'Script Output:          None (failed before log init)\n'
    fi
  fi

  exit "$exit_code"
}

script_exit_handler() {
  # orig_cwd is set in init(); --help can exit before then.
  if [[ -n ${orig_cwd-} ]]; then
    cd "$orig_cwd"
  fi

  if [[ -n ${cron-} && -f ${script_output-} ]]; then
    rm "${script_output}"
  fi

  if [[ -n ${cleanup-} ]]; then
    docker_cleanup
  fi

  if [[ -d ${script_lock-} ]]; then
    rmdir "$script_lock"
  fi

  printf '%b' "${ta_none-}"
}

cron_init() {
  if [[ -n ${cron-} ]]; then
    readonly script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
    exec 3>&1 4>&2 1>"$script_output" 2>&1
  fi
}

script_usage() {
  cat << EOF
Usage:
     -h, --help                                              Displays this help
         --dry-run                                          Print commands
      without running them (no cluster required)
         --argocd                                           Install Argo CD
      (Chapter 19)
         --monitoring                                       Install Prometheus
      and Grafana (Chapter 20)
         --otel                                             Install
      OpenTelemetry (Chapter 21)
     -q, --quiet                                             Disables verbose
       output
    -nc, --no-colour                                         Disables colour
      output
    -cr, --cron                                              Run silently unless
      we encounter an error
    -cb, --clean-build                                       Force Docker rebuild
      without cache
     -i, --install                                           Installs the
       Kubernetes System
    -ia, --install-all-dependencies                          Install all
      dependencies
    -k, --kind                                           Run on Kind mode
     -t, --interactive                                       Interactive mode

    -id=SERVICE,
      --install-dependency=SERVICE                Install a core
      dependency (comma-separated)
    -im=MODULE,
      --install-module-dependency=MODULE           Install runtime
      module(s) dependency (comma-separated)
    -ic=COMPONENT,
      --install-component-dependency=COMPONENT  Install runtime
      component(s) dependency (comma-separated)
    -ba=SERVICE,
      --build-backend-services=SERVICE              Builds
      backend/core services (comma-separated)

    -bi, --build-images                                      Builds docker
      images
    -bc, --build-project-containers                          Builds all project
      containers
    -ra, --reload-backend-services                             Reload backend
      services
    -rc=SERVICE,
      --reload-core-services=SERVICE             Reload core services
    -rk, --reload-kubernetes                                 Reload the
      kubernetes system
    -rs, --reload-services                                   Reload all services

    -ks, --kind-start,
      start                                   Start Kind
      cluster
      (requires --kind)
    -kt, --kind-stop,
      stop                                     Stop Kind cluster
      (requires --kind)
    -kd, --kind-delete,
      delete                                 Delete Kind cluster
      (requires --kind)

Exit codes:
     0  Normal exit
     1  External error (missing binary, failed command,
       network error)
     2  Script error (missing argument, invalid configuration)

Sample usage:

  Install all dependencies, rebuild containers,
    and reload services:
  \$ $0 -id=guardian,conductor -im=frontier,cache -bc -rs

  Start a fresh local cluster in Kind mode:
  \$ $0 --kind --install

  Reload a single service after a code change:
  \$ $0 --kind -rc=conductor
EOF
}

parse_params() {
  local param
  while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case $param in
      -h|--help)
        script_usage
        exit 0
        ;;
      --dry-run)
        # Not specified in the book. Safe inspection without a cluster.
        dry_run=true
        ;;
      --argocd)
        # Not in the Ch10 flag list; added so argocd_init (Ch18/19) can run.
        install_argocd=true
        cleanup=true
        ;;
      --monitoring)
        # Not in the Ch10 flag list; added so monitoring_init (Ch18/20) can run.
        install_monitoring=true
        cleanup=true
        ;;
      --otel)
        # Not in the Ch10 flag list; added so otel_init (Ch18/21) can run.
        install_otel=true
        cleanup=true
        ;;
      -t|--interactive)
        interactive=true
        ;;
      -v|--verbose)
        verbose=true
        ;;
      -q|--quiet)
        verbose=
        ;;
      -nc|--no-colour)
        no_colour=true
        ;;
      -cr|--cron)
        cron=true
        ;;
      -cb|--clean-build)
        clean_build=true
        ;;
      -k|--kind)
        with_kind=true
        ;;
      -ia|--install-all-dependencies|ideps)
        install_all_deps=true
        cleanup=true
        ;;
      -id=*|--install-dependency=*)
        install_single_deps="${param#*=}"
        cleanup=true
        ;;
      -im=*|--install-module-dependency=*)
        install_module_deps="${param#*=}"
        cleanup=true
        ;;
      -ic=*|--install-component-dependency=*)
        install_component_deps="${param#*=}"
        cleanup=true
        ;;

      # --- Build & Reload Flags ---

      -bc|--build-project-containers|build_project_containers)
        build_project_containers=true
        cleanup=true
        ;;
      -bi|--build-images|build_images)
        build_images=true
        cleanup=true
        ;;
      -ba=*|--build-backend-services=*)
        build_backend_services="${param#*=}"
        cleanup=true
        ;;
      --build-guardian|build_guardian)
        build_services=true
        build_guardian=true
        cleanup=true
        ;;
      --build-seeder|build_seeder)
        build_services=true
        build_seeder=true
        cleanup=true
        ;;
      -ra|--reload-backend-services|reload_backend)
        build_project_containers=true
        reload_backend_services=true
        cleanup=true
        ;;
      -rc=*|--reload-core-services=*)
        kubectl_restart="${param#*=}"
        cleanup=true
        ;;
      -rk|--reload-kubernetes|reload_kubernetes)
        reload_all_kubernetes=true
        cleanup=true
        ;;
      -rs|--reload-services|reload_services)
        reload_services=true
        reload_all=true
        cleanup=true
        ;;
      -i|--install|install)
        setup_k8s
        exit 0
        ;;
      -ks|--kind-start|start)
        start_env
        exit 0
        ;;
      -kt|--kind-stop|stop)
        stop_env
        exit 0
        ;;
      -kd|--kind-delete|delete)
        delete_env
        exit 0
        ;;
      build_backend)
        build_backend_services "${@-}"
        exit 0
        ;;
      ionedep)
        install_deps "${@-}"
        exit 0
        ;;
      reload_core)
        kubectl_restart "${@-}"
        exit 0
        ;;
      *)
        script_exit "Invalid parameter was provided: ${param-}" 2
        ;;
    esac
  done
}


init() {
  readonly orig_cwd="$PWD"
  readonly script_path="${BASH_SOURCE[0]}"
  readonly script_dir="$(dirname "$script_path")"
  readonly script_name="$(basename "$script_path")"
  readonly script_params="$*"
  readonly ta_none="$(tput sgr0 2> /dev/null || true)"

  # Colour vars are used by log() in get_kube_params / check_repos.
  # main() also calls colour_init afterwards (idempotent).
  colour_init

  # Book (Ch18) also calls the dispatcher functions from init(). main()
  # runs init() before parse_params, so those flags would still be unset.
  # Runtime checks and dispatchers run after parse_params instead (see
  # run_operations). Under --help/--dry-run, skip cluster-dependent checks.
  if [[ -z ${skip_runtime_checks-} ]]; then
    check_required_binaries
    get_kube_params
    check_repos
  fi
}

# The book's init() lists these dispatchers. They run here, after
# parse_params and lock_init, so the flags they inspect are actually set.
run_operations() {
  install_deps_init
  build_images_init
  reload_services_init
  reload_kubernetes_init
  argocd_init
  monitoring_init
  otel_init
}

# Not specified in the book: honour --help and --dry-run before init's
# binary, repository, and configuration requirements, so they work
# without a cluster or a configuration file.
early_flags() {
  local arg
  for arg in "${@-}"; do
    case "$arg" in
      -h|--help)
        colour_init
        script_usage
        exit 0
        ;;
      --dry-run)
        dry_run=true
        skip_runtime_checks=true
        ;;
      -k|--kind)
        # Honour --kind before init() so Kind-mode binary checks apply
        # and get_kube_params does not require a host kubelet / cluster.
        with_kind=true
        ;;
    esac
  done
}

main() {
  trap script_err_handler ERR
  trap script_exit_handler EXIT

  early_flags "${@-}"

  init "${@-}"
  colour_init

  if [ ! -f "${orig_cwd-}/configuration" ]; then
    if [[ -n ${dry_run-} ]]; then
      # Not specified in the book. Under --dry-run, load the example
      # configuration if present and continue without prompting.
      if [[ -f "${orig_cwd-}/configuration.example" ]]; then
        # shellcheck disable=SC1091
        source "${orig_cwd-}/configuration.example"
        log "DRY-RUN: no configuration file; using configuration.example" "$fg_yellow"
      else
        log "DRY-RUN: no configuration file; continuing with empty credentials" "$fg_yellow"
      fi
    else
      log "Configuration file is missing."
      echo "Do you wish to configure the file?"
      select yn in "Yes" "No"; do
        case "${yn-}" in
          Yes ) get_configurations; script_exit 'Configuration saved!' 2 ;;
          No )  exit 0 ;;
        esac
      done
    fi
  else
    # shellcheck disable=SC1091
    source "${orig_cwd-}/configuration"
    readonly GITHUB_USER="${github_user-}"
    readonly GITHUB_TOKEN="${github_token-}"
    readonly DOCKER_NETWORK_MODE="${docker_network_mode-}"
  fi

  if [[ -z "${*-}" ]]; then
    script_usage
    exit 0
  fi

  parse_params "${@-}"

  cron_init

  if [[ -z ${dry_run-} ]]; then
    lock_init system
  else
    log "DRY-RUN: skipping lock_init" "$fg_yellow"
  fi

  run_operations
}

main "$@"
