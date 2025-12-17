#!/bin/bash
# Bonus Part - Setup (run during Packer build)
# Pre-downloads all required images and repositories for fast deployment

set -euo pipefail

echo "================================"
echo "Bonus Setup - Pre-caching Dependencies"
echo "================================"

# Check prerequisites
echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }
command -v k3d >/dev/null 2>&1 || { echo "ERROR: k3d not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }

echo "================================"
echo "Pre-pulling Docker images..."
echo "================================"

# Check for Docker Hub authentication (optional)
if [ -n "${DOCKER_USERNAME:-}" ] && [ -n "${DOCKER_PASSWORD:-}" ]; then
    echo "Docker Hub credentials detected, logging in..."
    echo "${DOCKER_PASSWORD}" | sudo docker login -u "${DOCKER_USERNAME}" --password-stdin
else
    echo "No Docker Hub credentials found (using anonymous access)"
    echo "Note: Set DOCKER_USERNAME and DOCKER_PASSWORD env vars to avoid rate limits"
fi

# Function to pull Docker image with retry logic
pull_with_retry() {
    local image="$1"
    local max_attempts=5
    local attempt=1
    local wait_time=30  # Increased from 10s to 30s for rate limit recovery

    echo "Pulling ${image}..."

    while [ $attempt -le $max_attempts ]; do
        if sudo docker pull "${image}" 2>&1; then
            echo "✓ Successfully pulled ${image}"
            return 0
        else
            local exit_code=$?
            echo "✗ Pull attempt ${attempt}/${max_attempts} failed for ${image}"

            if [ $attempt -lt $max_attempts ]; then
                echo "  Waiting ${wait_time}s before retry..."
                sleep ${wait_time}
                # Exponential backoff: 30s, 60s, 120s, 240s
                wait_time=$((wait_time * 2))
                attempt=$((attempt + 1))
            else
                echo "ERROR: Failed to pull ${image} after ${max_attempts} attempts"
                echo "       This may be due to Docker Hub rate limits."
                echo "       Consider setting DOCKER_USERNAME and DOCKER_PASSWORD environment variables."
                return 1
            fi
        fi
    done
}

# Pull images with retry and longer delays between pulls to avoid rate limiting
# K3s images (latest stable: v1.34.2)
pull_with_retry "rancher/k3s:v1.34.2-k3s1"
sleep 5

# K3d images (latest stable)
pull_with_retry "ghcr.io/k3d-io/k3d-tools:5.8.3"
sleep 5
pull_with_retry "ghcr.io/k3d-io/k3d-proxy:5.8.3"
sleep 5

# ArgoCD images (latest stable: v3.2.0)
pull_with_retry "quay.io/argoproj/argocd:v3.2.0"
sleep 5

# Application images (Docker Hub - most likely to hit rate limits)
pull_with_retry "wil42/playground:v1"
sleep 5
pull_with_retry "wil42/playground:v2"
sleep 5
pull_with_retry "nginx:1.27-alpine"

echo "================================"
echo "Adding Helm repositories..."
echo "================================"

# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "================================"
echo "Bonus build complete!"
echo "================================"
echo "All dependencies cached."
echo "Run './run.sh' from bonus/ directory to deploy during defense."
