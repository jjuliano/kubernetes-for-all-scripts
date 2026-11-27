#!/usr/bin/env bash
# Pre-pull base images (Chapter 16). The book describes this as a
# simple script of docker pull commands; tag defaults are not specified.
set -o errexit
set -o nounset
set -o pipefail

docker pull "golang:${GO_VERSION:-1.22}"
docker pull "node:${NODE_VERSION:-20}"
docker pull postgres:16
docker pull registry:2
docker pull nginx:latest
# Kafka image tag is not specified in the book; skipped unless KAFKA_IMAGE is set.
if [[ -n ${KAFKA_IMAGE-} ]]; then
  docker pull "$KAFKA_IMAGE"
fi
