#!/bin/bash
# Root run script - Import and test VM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${IOT_OUTPUT_DIR:-/home/frthierr/sgoinfre/frthierr/iot-storage}"
OVA_PATH="${OUTPUT_DIR}/output-iot-eval/iot-eval-vm.ova"

echo "================================"
echo "Inception-of-Things VM Runner"
echo "================================"

# Set SSH key environment variable for packer-vm/run.sh
export IOT_SSH_KEY="${HOME}/.ssh/iot-vm-key"

# Call packer run script
"${SCRIPT_DIR}/packer-vm/run.sh" "${OVA_PATH}"
