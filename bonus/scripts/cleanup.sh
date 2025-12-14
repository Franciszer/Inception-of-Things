#!/bin/bash
set -euo pipefail

echo "================================"
echo "Cleaning up Bonus Part"
echo "================================"

# Delete K3d cluster
if k3d cluster list | grep -q bonus-cluster; then
    echo "Deleting K3d cluster..."
    k3d cluster delete bonus-cluster
    echo "Cluster deleted successfully"
else
    echo "No cluster found to delete"
fi

echo "================================"
echo "Cleanup complete!"
echo "================================"
