#!/usr/bin/env bash
# setup.sh — thin Kind-mode entry point (Chapter 1)
# Equivalent to: ./datacenter.sh --kind [FLAGS]
# From Kubernetes for All by Joel Bryan Juliano
# https://leanpub.com/k8s4all
# License: MIT (see LICENSE in the repository root)

set -o errexit
set -o nounset
set -o pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$_script_dir/datacenter.sh" --kind "${@-}"
