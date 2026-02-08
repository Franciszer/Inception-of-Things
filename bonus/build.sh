#!/bin/bash
# Pre-pull heavy Docker images so run.sh is faster during eval.
# GitLab CE alone is ~3GB.  Without pre-pulling, run.sh would spend
# several minutes downloading before it can even start.
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }

info "Pulling images..."
docker pull gitlab/gitlab-ce:latest    # ~3GB — GitLab (standalone container)
docker pull wil42/playground:v1        # the app, version 1
docker pull wil42/playground:v2        # the app, version 2
info "Done."
