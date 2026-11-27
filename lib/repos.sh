# lib/repos.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 5
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

get_repos_dir() {
  if is_kind; then
    echo "/services"
  else
    echo "${orig_cwd-}/services"
  fi
}
