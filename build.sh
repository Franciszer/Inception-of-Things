#!/bin/bash
# Root build script - Builds VM image with all parts pre-cached

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/media/frthierr/Vms/packer-iot"

echo "================================"
echo "Inception-of-Things VM Builder"
echo "================================"

# Call packer build script
"${SCRIPT_DIR}/packer-vm/build.sh" "${OUTPUT_DIR}"

echo ""
echo "VM build complete!"
echo "Run './run.sh' to test the VM"
