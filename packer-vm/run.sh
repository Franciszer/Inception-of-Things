#!/bin/bash
# VM Runner - Import, start, and test VM
# Usage: ./run.sh [ova_path]

set -euo pipefail

# Configuration
OVA_PATH="${1:-/media/frthierr/Vms/packer-iot/output-iot-eval/iot-eval-vm.ova}"
VM_NAME="iot-eval-vm"
SSH_PORT="2222"
SSH_USER="ychibani"
SSH_KEY_PATH="${IOT_SSH_KEY:-${HOME}/.ssh/iot-vm-key}"

echo "================================"
echo "VM Runner"
echo "================================"
echo "OVA: ${OVA_PATH}"
echo "SSH key: ${SSH_KEY_PATH}"

# Check if OVA exists
if [ ! -f "${OVA_PATH}" ]; then
    echo "ERROR: OVA file not found at ${OVA_PATH}"
    exit 1
fi

# Clean up old VM (idempotent)
echo "Cleaning up old VM..."
VBoxManage controlvm "${VM_NAME}" poweroff 2>/dev/null || true
sleep 2
VBoxManage unregistervm "${VM_NAME}" --delete 2>/dev/null || true

# Import VM
echo "Importing VM..."
VBoxManage import "${OVA_PATH}" --vsys 0 --vmname "${VM_NAME}"

# Configure networking
echo "Configuring networking..."
VBoxManage modifyvm "${VM_NAME}" --natpf1 "ssh,tcp,,${SSH_PORT},,22"

# Start VM
echo "Starting VM..."
VBoxManage startvm "${VM_NAME}" --type headless

# Wait for SSH
echo "Waiting for SSH..."
MAX_WAIT=120
ELAPSED=0
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           -o ConnectTimeout=5 -i "${SSH_KEY_PATH}" \
           -p "${SSH_PORT}" "${SSH_USER}@localhost" "echo 'SSH ready'" 2>/dev/null; do
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "ERROR: SSH not available after ${MAX_WAIT}s"
        exit 1
    fi
    echo "Waiting for SSH... (${ELAPSED}s/${MAX_WAIT}s)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done
echo "SSH is ready!"

echo ""
echo "================================"
echo "VM is running!"
echo "================================"
echo ""
echo "Connection info:"
echo "  SSH: ssh -i ${SSH_KEY_PATH} -p ${SSH_PORT} ${SSH_USER}@localhost"
echo ""
echo "Available parts (run from within VM):"
echo "  P1: cd ~/Inception-of-Things/p1 && ./run.sh"
echo "  P2: cd ~/Inception-of-Things/p2 && ./run.sh"
echo "  P3: cd ~/Inception-of-Things/p3 && ./run.sh"
echo "  Bonus: cd ~/Inception-of-Things/bonus && ./run.sh"
echo ""
echo "Stop VM:"
echo "  VBoxManage controlvm ${VM_NAME} poweroff"
echo ""
echo "✓ VM is ready for use!"
