#!/bin/bash
# Stop the K3d cluster without destroying it.
# GitLab runs inside the cluster, so stopping the cluster pauses everything.
# To restart: run.sh will clean and recreate from scratch.
# To remove everything: use clean.sh.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# k3d cluster stop pauses the K3d Docker containers (the K3s nodes)
# All pods (ArgoCD, GitLab, wil-playground) stop with the cluster.
k3d cluster stop bonus 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} Cluster stopped" \
  || echo -e "${RED}>>>${NC} No cluster to stop"
