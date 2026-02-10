#!/bin/bash
# Pre-pull heavy Docker images so run.sh is faster during eval.
# GitLab CE alone is ~3GB.  Without pre-pulling, the cluster would spend
# several minutes downloading before GitLab can even start.
#
# run.sh imports these images into K3d after cluster creation via
# `k3d image import`, so they don't need to be re-downloaded.
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }

info "Pulling images..."
docker pull gitlab/gitlab-ce:latest    # ~3GB — GitLab (runs in gitlab namespace)
docker pull wil42/playground:v1        # the app, version 1
docker pull wil42/playground:v2        # the app, version 2
info "Done."
