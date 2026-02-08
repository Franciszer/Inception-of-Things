#!/bin/bash
# Destroy cluster and GitLab container completely.
set -euo pipefail

k3d cluster delete iot 2>/dev/null && echo "Cluster deleted" || echo "No cluster"
docker rm -f gitlab-ce 2>/dev/null && echo "GitLab removed" || echo "No GitLab"
