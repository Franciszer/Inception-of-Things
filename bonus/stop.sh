#!/bin/bash
# Stop cluster and GitLab without destroying them.
# Use run.sh to start again, or clean.sh to remove everything.
set -euo pipefail

k3d cluster stop iot 2>/dev/null && echo "Cluster stopped" || echo "No cluster to stop"
docker stop gitlab-ce 2>/dev/null && echo "GitLab stopped" || echo "No GitLab to stop"
