# lib/logging.sh
# Colour initialization and logging for datacenter.sh
# From Kubernetes for All by Joel Bryan Juliano
# https://leanpub.com/k8s4all
# Companion repository: https://github.com/jjuliano/kubernetes-for-all-scripts
# License: MIT (see LICENSE in the repository root)

# Allow this file to be sourced on its own for the Chapter 6 exercises.
if ! declare -F script_exit > /dev/null 2>&1; then
  script_exit() {
    printf '%s\n' "${1-}" >&2
    exit "${2:-1}"
  }
fi

# Try tput; if it produces no output, use the ANSI fallback.
tput_or_ansi() {
  local ansi="$1"
  shift
  local seq
  seq="$(tput "$@" 2> /dev/null || true)"
  if [[ -n $seq ]]; then
    printf '%s' "$seq"
  else
    printf '%b' "$ansi"
  fi
}

colour_init() {
  if [[ -n ${no_colour-} || -n ${NO_COLOR-} ]] || ! [[ -t 1 ]]; then
    readonly ta_bold=""
    readonly ta_uscore=""
    readonly ta_blink=""
    readonly ta_reverse=""
    readonly ta_conceal=""
    readonly fg_black=""
    readonly fg_red=""
    readonly fg_green=""
    readonly fg_yellow=""
    readonly fg_blue=""
    readonly fg_magenta=""
    readonly fg_cyan=""
    readonly fg_white=""
    readonly bg_black=""
    readonly bg_red=""
    readonly bg_green=""
    readonly bg_yellow=""
    readonly bg_blue=""
    readonly bg_magenta=""
    readonly bg_cyan=""
    readonly bg_white=""
    return 0
  fi

  local reset="${ta_none-}"
  [[ -n $reset ]] || reset=$'\033[0m'

  readonly ta_bold="$(tput_or_ansi '\033[1m' bold)"
  printf '%b' "$reset"
  readonly ta_uscore="$(tput_or_ansi '\033[4m' smul)"
  printf '%b' "$reset"
  readonly ta_blink="$(tput_or_ansi '\033[5m' blink)"
  printf '%b' "$reset"
  readonly ta_reverse="$(tput_or_ansi '\033[7m' rev)"
  printf '%b' "$reset"
  readonly ta_conceal="$(tput_or_ansi '\033[8m' invis)"
  printf '%b' "$reset"

  readonly fg_black="$(tput_or_ansi '\033[30m' setaf 0)"
  printf '%b' "$reset"
  readonly fg_red="$(tput_or_ansi '\033[31m' setaf 1)"
  printf '%b' "$reset"
  readonly fg_green="$(tput_or_ansi '\033[32m' setaf 2)"
  printf '%b' "$reset"
  readonly fg_yellow="$(tput_or_ansi '\033[33m' setaf 3)"
  printf '%b' "$reset"
  readonly fg_blue="$(tput_or_ansi '\033[34m' setaf 4)"
  printf '%b' "$reset"
  readonly fg_magenta="$(tput_or_ansi '\033[35m' setaf 5)"
  printf '%b' "$reset"
  readonly fg_cyan="$(tput_or_ansi '\033[36m' setaf 6)"
  printf '%b' "$reset"
  readonly fg_white="$(tput_or_ansi '\033[37m' setaf 7)"
  printf '%b' "$reset"

  readonly bg_black="$(tput_or_ansi '\033[40m' setab 0)"
  printf '%b' "$reset"
  readonly bg_red="$(tput_or_ansi '\033[41m' setab 1)"
  printf '%b' "$reset"
  readonly bg_green="$(tput_or_ansi '\033[42m' setab 2)"
  printf '%b' "$reset"
  readonly bg_yellow="$(tput_or_ansi '\033[43m' setab 3)"
  printf '%b' "$reset"
  readonly bg_blue="$(tput_or_ansi '\033[44m' setab 4)"
  printf '%b' "$reset"
  readonly bg_magenta="$(tput_or_ansi '\033[45m' setab 5)"
  printf '%b' "$reset"
  readonly bg_cyan="$(tput_or_ansi '\033[46m' setab 6)"
  printf '%b' "$reset"
  readonly bg_white="$(tput_or_ansi '\033[47m' setab 7)"
  printf '%b' "$reset"
}
log() {
  if [[ $# -lt 1 ]]; then
    script_exit 'Missing required argument to log()!' 2
  fi

  if [[ -z ${no_colour-} ]]; then
    if [[ -n ${2-} ]]; then
      printf '%b' "$2"
    else
      printf '%b' "$fg_green"
    fi
  fi

  if [[ -n ${3-} ]]; then
    printf '%s%b' "$1" "${ta_none-}"
  else
    printf '%s%b\n' "$1" "${ta_none-}"
  fi
}
verbose_print() {
  if [[ -n ${verbose-} ]]; then
    log "$@"
  fi
}
