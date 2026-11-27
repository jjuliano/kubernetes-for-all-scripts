#!/usr/bin/env bash
# Pre-pull base images (Chapter 16).
set -o errexit
set -o nounset
set -o pipefail

docker pull "golang:${GO_VERSION:-1.22}"
docker pull "python:3.12-alpine"
docker pull "node:${NODE_VERSION:-20}"
docker pull postgres:16
docker pull registry:2
docker pull nginx:latest
docker pull "${KAFKA_IMAGE:-apache/kafka:3.9.1}"
docker pull traefik:v3.3
