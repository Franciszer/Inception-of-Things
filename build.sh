#!/bin/bash
# Root build script - Builds VM image with all parts pre-cached

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${IOT_OUTPUT_DIR:-/home/frthierr/sgoinfre/frthierr/iot-storage}"
PACKER_DIR="${SCRIPT_DIR}/packer-vm"
PACKER_VERSION="1.11.2"
LOG_FILE="/tmp/iot-build-$(date +%Y%m%d-%H%M%S).log"

# Function that does the actual build
do_build() {
    set -euo pipefail

    # Record start time
    START_TIME=$(date +%s)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Build started"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================"

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

    # Call packer build script with timestamps
    # Use 'ts' if available, otherwise use while read loop for timestamps
    if command -v ts >/dev/null 2>&1; then
        "${PACKER_DIR}/build.sh" "${OUTPUT_DIR}" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]'
    else
        "${PACKER_DIR}/build.sh" "${OUTPUT_DIR}" 2>&1 | while IFS= read -r line; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line"
        done
    fi

    # Calculate total build time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VM build complete!"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Build duration: ${MINUTES}m ${SECONDS}s"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VM image: ${OUTPUT_DIR}/output-iot-eval/iot-eval-vm.ova"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file: ${LOG_FILE}"
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Run './run.sh' to test the VM"
}

# Run build in background and redirect to log file
do_build > "${LOG_FILE}" 2>&1 &
BUILD_PID=$!

# Print info to user
echo "================================"
echo "Inception-of-Things VM Builder"
echo "================================"
echo "Build PID: ${BUILD_PID}"
echo "Output dir: ${OUTPUT_DIR}"
echo "Log file: ${LOG_FILE}"
echo ""
echo "Monitor progress:"
echo "  tail -f ${LOG_FILE}"
echo ""
echo "To use a different output directory:"
echo "  export IOT_OUTPUT_DIR=/your/path"
echo ""
echo "This will take 60-90 minutes..."
echo "================================"
