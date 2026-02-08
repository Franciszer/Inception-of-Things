#!/bin/bash
# Destroy cluster and GitLab container completely.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

k3d cluster delete iot 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} Cluster deleted" \
  || echo -e "${RED}>>>${NC} No cluster"
docker rm -f gitlab-ce 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} GitLab removed" \
  || echo -e "${RED}>>>${NC} No GitLab"
