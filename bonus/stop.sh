#!/bin/bash
# Bonus Part - Stop (cleanup)
# Destroys the k3d cluster and cleans up resources

set -euo pipefail

echo "================================"
echo "Bonus Part - Cleanup"
echo "================================"

# Check if cluster exists
if k3d cluster list | grep -q bonus-cluster; then
    echo "Deleting k3d cluster 'bonus-cluster'..."
    k3d cluster delete bonus-cluster
    echo "Cluster deleted successfully."
else
    echo "No cluster named 'bonus-cluster' found."
fi

echo ""
echo "================================"
echo "Cleanup complete!"
echo "================================"
echo "Run './run.sh' from bonus/ directory to deploy again."
