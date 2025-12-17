#!/bin/bash
# Root build script - Builds VM image with all parts pre-cached

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/media/frthierr/Vms/packer-iot"
PACKER_DIR="${SCRIPT_DIR}/packer-vm"
PACKER_VERSION="1.11.2"
LOG_FILE="/tmp/iot-build-$(date +%Y%m%d-%H%M%S).log"

# Function that does the actual build
do_build() {
    set -euo pipefail

    # Install Packer locally if not present
    if [ ! -f "${PACKER_DIR}/packer" ]; then
        echo "Installing Packer ${PACKER_VERSION} locally..."
        cd "${PACKER_DIR}"

        # Detect architecture
        ARCH=$(uname -m)
        case ${ARCH} in
            x86_64)
                PACKER_ARCH="amd64"
                ;;
            aarch64|arm64)
                PACKER_ARCH="arm64"
                ;;
            *)
                echo "ERROR: Unsupported architecture: ${ARCH}"
                exit 1
                ;;
        esac

        # Download and install Packer
        PACKER_ZIP="packer_${PACKER_VERSION}_linux_${PACKER_ARCH}.zip"
        echo "Downloading ${PACKER_ZIP}..."
        curl -LO "https://releases.hashicorp.com/packer/${PACKER_VERSION}/${PACKER_ZIP}"

        # Extract
        unzip -q "${PACKER_ZIP}"
        rm "${PACKER_ZIP}"
        chmod +x packer

        echo "Packer ${PACKER_VERSION} installed successfully"
        cd "${SCRIPT_DIR}"
    else
        echo "Packer already installed at ${PACKER_DIR}/packer"
    fi

    # Call packer build script
    "${PACKER_DIR}/build.sh" "${OUTPUT_DIR}"

    echo ""
    echo "================================"
    echo "VM build complete!"
    echo "================================"
    echo "VM image: ${OUTPUT_DIR}/output-iot-eval/iot-eval-vm.ova"
    echo "Log file: ${LOG_FILE}"
    echo ""
    echo "Run './run.sh' to test the VM"
}

# Run build in background and redirect to log file
do_build > "${LOG_FILE}" 2>&1 &
BUILD_PID=$!

# Print info to user
echo "================================"
echo "Inception-of-Things VM Builder"
echo "================================"
echo "Build PID: ${BUILD_PID}"
echo "Log file: ${LOG_FILE}"
echo ""
echo "Monitor progress:"
echo "  tail -f ${LOG_FILE}"
echo ""
echo "This will take 60-90 minutes..."
echo "================================"
