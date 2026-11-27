# lib/superuser.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 5
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

run_as_root() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to run_as_root()!' 2
  fi

  check_binary sudo && sudo "${@-}"
}
