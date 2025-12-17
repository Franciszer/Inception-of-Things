#!/bin/bash
# Packer VM Builder - Idempotent VM image builder
# Usage: ./build.sh [output_directory]

set -euo pipefail

# Configuration
OUTPUT_DIR="${1:-/media/frthierr/Vms/packer-iot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_KEY_DIR="${HOME}/.ssh"
SSH_KEY_NAME="iot-vm-key"
SSH_KEY_PATH="${SSH_KEY_DIR}/${SSH_KEY_NAME}"

# Export SSH key path for Packer to use
export IOT_SSH_KEY="${SSH_KEY_PATH}"

echo "================================"
echo "Packer VM Builder"
echo "================================"
echo "Output directory: ${OUTPUT_DIR}"
echo "SSH key: ${SSH_KEY_PATH}"

# Generate SSH key if it doesn't exist
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "Generating SSH key..."
    mkdir -p "${SSH_KEY_DIR}"
    ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -N "" -C "iot-vm-key"
    echo "SSH key generated at ${SSH_KEY_PATH}"
else
    echo "SSH key already exists at ${SSH_KEY_PATH}"
fi

# Change to packer directory
cd "${SCRIPT_DIR}"

# Clean output directory if it exists (idempotent)
rm -rf "${OUTPUT_DIR}/output-iot-eval"

# Initialize Packer
echo "Initializing Packer..."
./packer init iot-eval.pkr.hcl

# Validate Packer configuration
echo "Validating Packer configuration..."
./packer validate iot-eval.pkr.hcl

# Build VM
echo "Building VM..."
echo "This will take 60-90 minutes..."
./packer build \
    -var "output_directory=${OUTPUT_DIR}/output-iot-eval" \
    iot-eval.pkr.hcl

echo ""
echo "================================"
echo "Build complete!"
echo "================================"
echo "VM image: ${OUTPUT_DIR}/output-iot-eval/iot-eval-vm.ova"
echo "SSH key: ${SSH_KEY_PATH}"
echo ""
echo "Run './run.sh' to test the VM"
