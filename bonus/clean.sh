#!/bin/bash
# Destroy the K3d cluster completely.
# GitLab runs inside the cluster, so deleting the cluster removes everything:
# all Kubernetes resources, Docker containers (K3d nodes), and the Docker network.
# Use this for a fresh start before running run.sh again.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# k3d cluster delete removes all K3d containers + the Docker network
k3d cluster delete bonus 2>/dev/null \
  && echo -e "${GREEN}>>>${NC} Cluster deleted" \
  || echo -e "${RED}>>>${NC} No cluster"
