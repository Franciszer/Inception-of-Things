#!/bin/bash
# Pre-pull heavy images so run.sh is faster during eval.
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }

info "Pulling images..."
docker pull gitlab/gitlab-ce:latest
docker pull wil42/playground:v1
docker pull wil42/playground:v2
info "Done."
