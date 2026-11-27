# lib/script.sh
# From Kubernetes for All by Joel Bryan Juliano — Chapters 5, 7, and 9
# https://leanpub.com/k8s4all
# https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

check_binary() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to check_binary()!' 2
  fi

  if ! command -v "$1" > /dev/null 2>&1; then
    if [[ -n ${2-} ]]; then
      script_exit "Missing dependency: Couldn't locate $1." 1
    else
      script_exit "Missing dependency: $1." 2
    fi
  fi

  return 0
}

check_required_binaries() {
  readonly required_binaries=(docker helm kubectl sed ip systemctl git)

  for bin in "${required_binaries[@]-}"; do
    check_binary "${bin-}"
  done

  is_kind && check_binary kind

  return 0
}

is_kind() {
  [[ -n "${with_kind-}" ]] || return 1
  # The book also verifies `kind` is on PATH. Under --dry-run, skip the
  # binary check so the script can be inspected without Kind installed.
  if [[ -n ${dry_run-} ]]; then
    return 0
  fi
  check_binary kind
}

check_arguments() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to check_arguments()!' 2
  fi

  for var in "${@-}"; do
    local key="${var-}"
    local val="${!key-}"

    if [[ -z "${val-}" ]]; then
      script_exit "Missing variable dependency: Couldn't find a declared variable named ${key-}." 1
    else
      verbose_print "Found variable ${key-} with value ${val-}."
    fi
  done

  return 0
}

check_directories() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to check_directories()!' 2
  fi

  for directory in "${@-}"; do
    if [[ ! -d "${directory-}" ]]; then
      if [[ -n ${dry_run-} ]]; then
        log "DRY-RUN: missing directory ${directory-} (continuing)" "$fg_yellow"
        return 0
      fi
      script_exit "Missing directory dependency: Couldn't find directory ${directory-}." 1
    fi
  done

  return 0
}

check_files() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to check_files()!' 2
  fi

  for file in "${@-}"; do
    if [[ ! -f "${file-}" ]]; then
      if [[ -n ${dry_run-} ]]; then
        log "DRY-RUN: missing file ${file-} (continuing)" "$fg_yellow"
        return 0
      fi
      script_exit "Missing variable dependency: Couldn't find file ${file-}." 1
    fi
  done

  return 0
}

check_repos() {
  log "Checking service repositories ..." "$ta_bold$fg_blue"

  local repos_dir
  repos_dir="$(get_repos_dir)"

  if [[ ! -d "${repos_dir}" ]]; then
    script_exit "Service repositories directory not found: ${repos_dir}" 2
  fi

  for repo in backend guardian conductor seeder logger registry pds scanner cache frontier bridge; do
    if [[ ! -d "${repos_dir}/${repo}" ]]; then
      script_exit "Required repository missing: ${repos_dir}/${repo}" 2
    fi
  done
}

build_path() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to build_path()!' 2
  fi

  local new_path path_entry temp_path

  temp_path="$1:"
  if [[ -n ${2-} ]]; then
    temp_path="$temp_path$2:"
  fi

  new_path=
  while [[ -n $temp_path ]]; do
    path_entry="${temp_path%%:*}"
    case "$new_path:" in
      *:"$path_entry":*) ;;
      *) new_path="$new_path:$path_entry"
        ;;
    esac
    temp_path="${temp_path#*:}"
  done

  build_path="${new_path#:}"
}

lock_init() {
  local lock_dir
  if [[ $1 = 'system' ]]; then
    lock_dir="/tmp/$script_name.lock"
  elif [[ $1 = 'user' ]]; then
    lock_dir="/tmp/$script_name.$UID.lock"
  else
    script_exit 'Missing or invalid argument to lock_init()!' 2
  fi

  if mkdir "$lock_dir" 2> /dev/null; then
    readonly script_lock="$lock_dir"
    verbose_print "Acquired script lock: $script_lock"
  else
    script_exit "Unable to acquire script lock: $lock_dir" 2
  fi
}
