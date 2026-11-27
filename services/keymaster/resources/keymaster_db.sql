-- keymaster schema (sample; the book names this file but does not print it)
CREATE DATABASE keymaster;
\connect keymaster
CREATE TABLE IF NOT EXISTS keys (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
