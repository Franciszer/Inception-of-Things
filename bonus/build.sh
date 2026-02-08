#!/bin/bash
# Pre-pull heavy images so run.sh is faster during eval.
set -euo pipefail

echo "Pulling images..."
docker pull gitlab/gitlab-ce:latest
docker pull wil42/playground:v1
docker pull wil42/playground:v2
echo "Done."
