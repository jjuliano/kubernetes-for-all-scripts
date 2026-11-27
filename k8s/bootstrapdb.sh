#!/bin/sh
# Create application roles and databases (Chapter 13).
# Mounted into the postgres pod at /scripts/bootstrap.sh.
set -eu
export PGPASSWORD="${POSTGRES_PASSWORD:-}"
psql -v ON_ERROR_STOP=1 -U postgres -d postgres <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'myapp') THEN
    CREATE ROLE myapp LOGIN PASSWORD 'changeme-in-production';
  END IF;
END
$$;
SELECT 'CREATE DATABASE keymaster OWNER myapp'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keymaster')\gexec
SELECT 'CREATE DATABASE datastore OWNER myapp'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'datastore')\gexec
SELECT 'CREATE DATABASE metadata OWNER myapp'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metadata')\gexec
GRANT ALL PRIVILEGES ON DATABASE keymaster TO myapp;
GRANT ALL PRIVILEGES ON DATABASE datastore TO myapp;
GRANT ALL PRIVILEGES ON DATABASE metadata TO myapp;
SQL
echo "bootstrapdb: roles and databases ready"
