# services/

Service source repositories live here (or, in Kind mode, the book uses
`/services`). `check_repos` expects: backend, guardian, conductor, seeder,
logger, registry, pds, scanner, cache, frontier, bridge, and (for the router
build) router. The book treats these as git submodules; they are not bundled
in this repository.
