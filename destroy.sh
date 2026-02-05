#!/bin/bash
# Destroy script - Clean up VM and resources

set -euo pipefail

VM_NAME="iot-eval-vm"

echo "================================"
echo "Inception-of-Things Destroyer"
echo "================================"

# Stop VM if running
if VBoxManage list runningvms | grep -q "${VM_NAME}"; then
    echo "Stopping VM ${VM_NAME}..."
    VBoxManage controlvm "${VM_NAME}" poweroff 2>/dev/null || true
    sleep 3
fi

# Unregister and delete VM
if VBoxManage list vms | grep -q "${VM_NAME}"; then
    echo "Deleting VM ${VM_NAME}..."
    VBoxManage unregistervm "${VM_NAME}" --delete 2>/dev/null || true
fi

# Clean up SSH known_hosts
echo "Cleaning SSH known_hosts..."
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "[localhost]:2222" 2>/dev/null || true

echo ""
echo "================================"
echo "Cleanup complete!"
echo "================================"
echo "VM and resources removed."
echo "Run './build.sh' to rebuild the VM."
