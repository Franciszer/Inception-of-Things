#!/bin/bash
# Stop cluster and GitLab without destroying them.
# Use run.sh to start again, or clean.sh to remove everything.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

k3d cluster stop iot 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} Cluster stopped" \
  || echo -e "${RED}>>>${NC} No cluster to stop"
docker stop gitlab-ce 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} GitLab stopped" \
  || echo -e "${RED}>>>${NC} No GitLab to stop"
