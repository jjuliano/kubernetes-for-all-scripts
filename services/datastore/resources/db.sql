-- datastore schema (sample; the book names this file but does not print it)
CREATE DATABASE datastore;
\connect datastore
CREATE TABLE IF NOT EXISTS records (
  id SERIAL PRIMARY KEY,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
