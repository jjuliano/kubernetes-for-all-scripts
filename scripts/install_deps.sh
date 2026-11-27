#!/usr/bin/env bash
# Go dependency installer invoked by install_deps() via safe_docker_run
# (Chapter 15). Mounted into the build container at /install_deps.sh.
set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR="${REPOS_DIR:-/go/src/github.com/myapp-dev}"

install_one() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "install_deps: skip missing $dir"
    return 0
  fi
  if [[ -f "$dir/go.mod" ]]; then
    echo "install_deps: go mod download in $dir"
    (cd "$dir" && go mod download)
  else
    echo "install_deps: no go.mod in $dir (ok for the sample services)"
  fi
}

targets=("$@")
if [[ ${#targets[@]} -eq 0 || "${targets[0]}" == "all" ]]; then
  targets=()
  while IFS= read -r d; do
    targets+=("$d")
  done < <(find "$ROOT_DIR" -mindepth 1 -maxdepth 3 -type d \( -name 'runtime-*' -o -name '.*' \) -prune -o -name go.mod -printf '%h\n' 2>/dev/null || true)
  # Also walk well-known service directories even without go.mod
  for d in "$ROOT_DIR"/* "$ROOT_DIR"/runtime-components/* "$ROOT_DIR"/runtime-modules/*; do
    [[ -d "$d" ]] && install_one "$d"
  done
  exit 0
fi

for name in "${targets[@]}"; do
  if [[ -d "$ROOT_DIR/$name" ]]; then
    install_one "$ROOT_DIR/$name"
  elif [[ -d "$ROOT_DIR/runtime-components/$name" ]]; then
    install_one "$ROOT_DIR/runtime-components/$name"
  elif [[ -d "$ROOT_DIR/runtime-modules/$name" ]]; then
    install_one "$ROOT_DIR/runtime-modules/$name"
  else
    echo "install_deps: no directory for $name" >&2
    exit 1
  fi
done
