#!/usr/bin/env bash
set -euo pipefail
echo "==> hadolint..."
if [ -f Dockerfile ]; then
  docker run --rm -i hadolint/hadolint < Dockerfile
fi
echo "==> Build image..."
docker build -t local/test:ci .
echo "==> trivy scan..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL --exit-code 1 local/test:ci
