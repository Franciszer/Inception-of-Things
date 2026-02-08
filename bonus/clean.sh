#!/bin/bash
# Destroy the K3d cluster and GitLab container completely.
# This removes all Kubernetes resources, Docker volumes, and GitLab data.
# Use this for a fresh start before running run.sh again.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# k3d cluster delete removes all K3d containers + the Docker network
k3d cluster delete iot 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} Cluster deleted" \
  || echo -e "${RED}>>>${NC} No cluster"

# docker rm -f force-removes the GitLab container + its anonymous volumes
docker rm -f gitlab-ce 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} GitLab removed" \
  || echo -e "${RED}>>>${NC} No GitLab"
