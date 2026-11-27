Sample microservice source for *Kubernetes for All*.

Backend services (`backend`, `guardian`, `conductor`), `router`, `webapp`,
and core services (`keymaster`, `datastore`, `migrator`, `herald`,
`myapp-auth`) live at the top level. Runtime components and modules live
under `runtime-components/` and `runtime-modules/`, with top-level
symlinks so `check_repos` (Chapter 7) finds them.

Each service is a small HTTP server with a Dockerfile. SQL used by
Postgres bootstrap lives in `keymaster/resources/`, `datastore/resources/`,
and `migrator/resources/`.
