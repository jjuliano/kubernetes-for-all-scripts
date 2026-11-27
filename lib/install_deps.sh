# lib/install_deps.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 15
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

install_deps() {
  if [[ $# -lt 1 ]]; then
    script_exit "Missing required argument to install_deps()!" 2
  fi

  safe_docker_run "golang:${GO_VERSION:-1.22}" /install_deps.sh "${@-}"
}

# Not printed as a complete function in the book. Ch18 says install_deps_init
# triggers Go dependency installation when the Ch10 flags are set.
install_deps_init() {
  if [[ -n ${install_all_deps-} ]]; then
    install_deps all
  fi
  if [[ -n ${install_single_deps-} ]]; then
    install_deps ${install_single_deps//,/ }
  fi
  if [[ -n ${install_module_deps-} ]]; then
    install_deps ${install_module_deps//,/ }
  fi
  if [[ -n ${install_component_deps-} ]]; then
    install_deps ${install_component_deps//,/ }
  fi
}
