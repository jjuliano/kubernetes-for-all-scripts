#!/bin/sh
# Load service SQL into the databases created by bootstrapdb.sh (Chapter 13).
# SQL files come from the postgres-init-sql ConfigMap mounted at /sql.
set -eu
export PGPASSWORD="${POSTGRES_PASSWORD:-}"
run_sql() {
  file="$1"
  if [ -f "$file" ]; then
    echo "load_sql: applying $file"
    # Files may contain \connect; feed them to the postgres database first.
    psql -v ON_ERROR_STOP=0 -U postgres -d postgres -f "$file"
  else
    echo "load_sql: missing $file" >&2
    exit 1
  fi
}
run_sql /sql/keymaster_db.sql
run_sql /sql/db.sql
run_sql /sql/InitMetadataStore.sql
echo "load_sql: done"
