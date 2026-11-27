# lib/repos.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 5
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

get_repos_dir() {
  # The book prints `echo /services` in Kind mode because extraMounts
  # expose the checkout at /services *inside the Kind node*. This script
  # runs on the host, so prefer the checkout's services/ directory when
  # it is present. Fall back to /services when running inside the node.
  if [[ -n ${orig_cwd-} && -d "${orig_cwd}/services" ]]; then
    echo "${orig_cwd}/services"
  elif is_kind && [[ -d /services ]]; then
    echo "/services"
  else
    echo "${orig_cwd-}/services"
  fi
}
