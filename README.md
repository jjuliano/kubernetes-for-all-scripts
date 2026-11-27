# Kubernetes for All — companion scripts

[![CI](https://github.com/jjuliano/kubernetes-for-all-scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/jjuliano/kubernetes-for-all-scripts/actions/workflows/ci.yml)

Companion scripts for [*Kubernetes for All*](https://leanpub.com/k8s4all) by Joel Bryan Juliano.

Book: [https://leanpub.com/k8s4all](https://leanpub.com/k8s4all)

This repository is the public script download for the book: `datacenter.sh`, the library files laid out in Chapter 18, Helm charts and manifests, sample microservices, and the Compose files the book names.

## Prerequisites

- Bash, Git, Docker, [Kind](https://kind.sigs.k8s.io/), `kubectl`, and [Helm](https://helm.sh/) 3
- Enough RAM and disk for a three-node Kind cluster plus Postgres, a registry, and the sample services
- Copy `configuration.example` to `configuration` and fill in `github_user`, `github_token`, and `docker_network_mode` before a live run (Chapter 8). Do not commit `configuration`.

`--help` and `--dry-run` do not need Docker, Kind, or a cluster.

## Quick start

```bash
git clone https://github.com/jjuliano/kubernetes-for-all-scripts.git
cd kubernetes-for-all-scripts
chmod +x datacenter.sh setup.sh
cp configuration.example configuration   # edit credentials if you have them

# Inspect without a cluster
./datacenter.sh --help
./datacenter.sh --dry-run --kind --install

# Create the Kind cluster, build images, and deploy the sample services
./datacenter.sh --kind --install

# After a code change, rebuild and roll a service
./datacenter.sh --kind -rc=conductor

# Reload all application services
./datacenter.sh --kind -rs

# Tear down the cluster
./datacenter.sh --kind --kind-delete
```

`./setup.sh` is the Chapter 1 entry point; it is equivalent to `./datacenter.sh --kind`.

On the host, service source is read from this checkout's `services/` directory. Inside Kind nodes, `kind-config.yaml` bind-mounts that same tree at `/services` (and `scripts/` at `/scripts`), as Chapter 11 describes.

## Flags

| Flag | What it does |
| --- | --- |
| `-h`, `--help` | Print usage and exit |
| `--dry-run` | Print commands without running them (no cluster required) |
| `-k`, `--kind` | Local Kind mode |
| `-i`, `--install` | Full provision (`setup_k8s`). With `--kind`, creates the cluster if needed |
| `-ks`, `--kind-start` | Create the Kind cluster |
| `-kt`, `--kind-stop` | Pause Kind node containers |
| `-kd`, `--kind-delete` | Delete the Kind cluster |
| `-bi`, `--build-images` | Build the router image |
| `-bc`, `--build-project-containers` | Build backend, runtime component, and runtime module images |
| `-ba=…`, `--build-backend-services=` | Build named backend services |
| `-rs`, `--reload-services` | Reload application services |
| `-ra`, `--reload-backend-services` | Reload backend services |
| `-rc=NAME`, `--reload-core-services=` | Rolling-restart a named deployment |
| `-rk`, `--reload-kubernetes` | Rebuild and redeploy the cluster workloads |
| `-ia`, `--install-all-dependencies` | Run `install_deps all` |
| `-id=`, `-im=`, `-ic=` | Install Go deps for a service, module, or component |
| `-t`, `--interactive` | Interactive configuration |
| `-v` / `-q` | Verbose / quiet |
| `-nc`, `--no-colour` | Disable colour (also honours `NO_COLOR`) |
| `-cr`, `--cron` | Redirect output for unattended runs |
| `-cb`, `--clean-build` | `docker build --no-cache` |
| `--argocd` | Install Argo CD (Chapter 19) |
| `--monitoring` | Install Prometheus + Grafana (Chapter 20) |
| `--otel` | Install the OpenTelemetry operator, Tempo, collector, and instrumentation (Chapter 21) |

## Layout

```
datacenter.sh        Main entry point and global set options (Ch1–4, Ch10, Ch18)
setup.sh             Thin entry point: exec datacenter.sh --kind (Ch1)
configuration.example
kind-config.yaml     Kind cluster config used by start_env (Ch11)
lib/                 Library files listed in Chapter 18
chapter-06-terminal-colors-and-logging/lib/logging.sh
k8s/                 Manifests, Helm charts, and docker_images.sh
services/            Sample microservice source (see below)
scripts/install_deps.sh
external/            Docker Compose (Kafka + nginx) and nginx templates
```

`chapter-06-terminal-colors-and-logging/lib/logging.sh` and `lib/logging.sh` are the same file.

### Sample services

`check_repos` (Chapter 7) expects: backend, guardian, conductor, seeder, logger, registry, pds, scanner, cache, frontier, and bridge. Builds also use `router`, `webapp`, and the core services `keymaster`, `datastore`, `migrator`, `herald`, and `myapp-auth`.

Runtime components live under `services/runtime-components/` and runtime modules under `services/runtime-modules/`, with top-level symlinks so `check_repos` finds them. Each service is a small HTTP server with a Dockerfile, `/health`, and `/metrics`. They are samples so `docker build`, `kind load`, and Helm deploy can be exercised end to end — not the production code from a private monorepo.

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
| 12 | Docker operations, Compose | `lib/docker.sh`, `external/` |
| 13 | kubectl resources, Postgres bootstrap | `lib/kubectl.sh`, `k8s/*.yaml`, `k8s/bootstrapdb.sh`, `k8s/load_sql.sh` |
| 14 | Helm charts | `lib/helm.sh`, `k8s/core-service`, `k8s/traefik`, `k8s/webapp`, config and volume charts, `*-values.yaml` |
| 15 | Image builds and dependency checks | `lib/build.sh`, `lib/install_deps.sh`, `lib/check.sh`, `scripts/install_deps.sh` |
| 16 | Cluster setup | `lib/kubernetes.sh`, `k8s/docker_images.sh` |
| 17 | Service and cluster reload | `lib/reload_services.sh`, `lib/reload_kubernetes.sh` |
| 18 | Full library layout and `init` / `main` | `datacenter.sh`, `lib/*.sh` |
| 19 | Argo CD | `lib/argocd.sh` |
| 20 | Prometheus and Grafana | `lib/monitoring.sh`, `k8s/myapp-servicemonitor.yaml` |
| 21 | OpenTelemetry | `lib/otel.sh`, `k8s/otel-collector.yaml`, `k8s/otel-instrumentation.yaml` |

## Chapter 6 — Terminal Colors and Logging

`lib/logging.sh` provides `tput_or_ansi`, `colour_init`, `log`, and `verbose_print`.

`colour_init` sets the text-attribute and 8-color foreground/background variables used by `log`. It leaves those variables empty when `--no-colour` is set (`no_colour`), when the `NO_COLOR` environment variable is set, or when standard output is not a terminal. It uses `tput` when available and falls back to ANSI escape sequences otherwise.

```bash
source lib/logging.sh
colour_init
log "Starting up..."
log "Warning" "$fg_yellow"
```

## License

MIT License. See [LICENSE](LICENSE). Copyright (c) 2026 Joel Bryan Juliano.
