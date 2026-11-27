# lib/config.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapter 8
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

get_configurations() {
  readonly scriptdir="${orig_cwd-}"

  read -p "Enter github username: " github_user
  read -p "Enter github token: " github_token

  echo "Select the docker network mode"
  select nm in "Host" "Bridge" "Overlay" "MacVLAN" "None"; do
    case $nm in
      Host )
        docker_mode="host"
        break
        ;;
      Bridge )
        docker_mode="bridge"
        break
        ;;
      Overlay )
        docker_mode="overlay"
        break
        ;;
      MacVLAN )
        docker_mode="macvlan"
        break
        ;;
      None )
        docker_mode="none"
        break
        ;;
    esac
  done

  if [[ -z ${github_user-} ]]; then
    script_exit "Could not acquire github username ..." 2
  elif [[ -z ${github_token-} ]]; then
    script_exit "Could not acquire github token ..." 2
  elif [[ -z ${docker_mode-} ]]; then
    script_exit "Could not acquire docker network mode ..." 2
  else
    echo "github_user='${github_user-}'" > "${scriptdir-}/configuration"
    echo "github_token='${github_token-}'" >> "${scriptdir-}/configuration"
    echo "docker_network_mode='${docker_mode-}'" >> "${scriptdir-}/configuration"
  fi
}
