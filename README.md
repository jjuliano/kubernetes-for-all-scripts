# Kubernetes for All — companion scripts

Companion scripts for [*Kubernetes for All*](https://leanpub.com/k8s4all) by Joel Bryan Juliano.

Book: [https://leanpub.com/k8s4all](https://leanpub.com/k8s4all)

This repository is the public script download for the book: `datacenter.sh`, the library files laid out in Chapter 18, and the Chapter 6 logging library. Files use the same paths the book describes.

## Quick start

```bash
chmod +x datacenter.sh setup.sh
./datacenter.sh --help
./datacenter.sh --dry-run --kind --install
./setup.sh --help
```

`./setup.sh` is the Chapter 1 entry point; it is equivalent to `./datacenter.sh --kind`.

`--help` and `--dry-run` are safe to run without Docker, kubectl, Helm, Kind, or a cluster. `--dry-run` prints the commands that would run and skips them.

Copy `configuration.example` to `configuration` and fill in `github_user`, `github_token`, and `docker_network_mode` before running real operations (Chapter 8). Do not commit `configuration`.

## Layout

```
datacenter.sh        Main entry point and global set options (Ch1–4, Ch10, Ch18)
setup.sh             Thin entry point: exec datacenter.sh --kind (Ch1)
configuration.example
kind-config.yaml     Minimal Kind cluster config used by start_env (Ch11)
lib/
  script.sh          Core utilities, validation, locking (Ch5, Ch7, Ch9)
  logging.sh         Colours and log function (Ch6)
  repos.sh           Repository path helper (Ch5)
  superuser.sh       Privilege escalation (Ch5)
  config.sh          Interactive configuration (Ch8)
  kind.sh            Kind cluster start / stop / delete (Ch11)
  docker.sh          Docker operations (Ch12)
  kubectl.sh         kubectl resource management (Ch13)
  helm.sh            Helm chart management (Ch14)
  build.sh           Service image builds (Ch15)
  install_deps.sh    Go dependency installation (Ch15)
  check.sh           Registry availability check (Ch15)
  kubernetes.sh      Cluster setup and parameters (Ch16)
  reload_services.sh Service-level reload (Ch17)
  reload_kubernetes.sh Full cluster reload (Ch17)
  argocd.sh          GitOps controller (Ch19)
  monitoring.sh      Prometheus + Grafana (Ch20)
  otel.sh            OpenTelemetry tracing (Ch21)
chapter-06-terminal-colors-and-logging/
  lib/logging.sh     Same Chapter 6 library, kept next to the chapter path
k8s/                 Manifests and docker_images.sh (named in the book)
services/            Service source checkouts (git submodules in the book)
scripts/             Build and helper scripts (named in Ch18)
external/            Docker Compose files (named in Ch18)
```

`chapter-06-terminal-colors-and-logging/lib/logging.sh` and `lib/logging.sh` are the same file.

## Chapter 6 — Terminal Colors and Logging

`lib/logging.sh` provides `tput_or_ansi`, `colour_init`, `log`, and `verbose_print`.

`colour_init` sets the text-attribute and 8-color foreground/background variables used by `log`. It leaves those variables empty when `--no-colour` is set (`no_colour`), when the `NO_COLOR` environment variable is set, or when standard output is not a terminal. It uses `tput` when available and falls back to ANSI escape sequences otherwise.

```bash
source lib/logging.sh
colour_init
log "Starting up..."
log "Warning" "$fg_yellow"
```


## Chapter mapping

| Chapter | What the book adds | Files in this repository |
| --- | --- | --- |
| 1 | `setup.sh` and the `datacenter.sh` entry point | `setup.sh`, `datacenter.sh` |
| 4 | `main`, traps, and usage | `datacenter.sh` |
| 5 | Path helpers, `repos.sh`, `superuser.sh` | `lib/script.sh`, `lib/repos.sh`, `lib/superuser.sh` |
| 6 | Terminal colours and logging | `lib/logging.sh` |
| 7–9 | Validation, configuration, locking | `lib/script.sh`, `lib/config.sh`, `configuration.example` |
| 10 | Command-line flags | `datacenter.sh` |
| 11 | Kind cluster lifecycle | `lib/kind.sh`, `kind-config.yaml` |
| 12 | Docker operations | `lib/docker.sh` |
| 13 | kubectl resources | `lib/kubectl.sh` |
| 14 | Helm charts | `lib/helm.sh` |
| 15 | Image builds and dependency checks | `lib/build.sh`, `lib/install_deps.sh`, `lib/check.sh` |
| 16 | Cluster setup (`setup_k8s`, registry, kube params) | `lib/kubernetes.sh`, `k8s/docker_images.sh` |
| 17 | Service and cluster reload | `lib/reload_services.sh`, `lib/reload_kubernetes.sh` |
| 18 | Full library layout and `init` / `main` | `datacenter.sh`, `lib/*.sh` |
| 19 | Argo CD | `lib/argocd.sh` |
| 20 | Prometheus and Grafana | `lib/monitoring.sh` |
| 21 | OpenTelemetry | `lib/otel.sh` |

## What this repository does not include

The book also describes `k8s/` Helm charts and manifests, `external/` Compose files, and `services/` application source (sixteen microservices, PostgreSQL, Kafka, and a web frontend). Those trees are not printed in full in the book and are not bundled here. `--dry-run` works without them; a live `--install` needs the manifests and service repositories as you build them from the chapters.

`--dry-run`, and the `--argocd`, `--monitoring`, and `--otel` flags that dispatch the Chapter 19–21 libraries, are small additions so the complete script can be inspected and the later chapters' `*_init` functions can be reached. They are marked in the source.

## License

MIT License. See [LICENSE](LICENSE). Copyright (c) 2026 Joel Bryan Juliano.
