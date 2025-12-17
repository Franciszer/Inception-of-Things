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

# K3s images (latest stable: v1.34.2)
sudo docker pull rancher/k3s:v1.34.2-k3s1

# K3d images (latest stable)
sudo docker pull ghcr.io/k3d-io/k3d-tools:5.8.3
sudo docker pull ghcr.io/k3d-io/k3d-proxy:5.8.3

# ArgoCD images (latest stable: v3.2.0)
sudo docker pull quay.io/argoproj/argocd:v3.2.0

# Application images
sudo docker pull wil42/playground:v1
sudo docker pull wil42/playground:v2
sudo docker pull nginx:1.27-alpine

echo "================================"
echo "Adding Helm repositories..."
echo "================================"

# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "================================"
echo "Bonus setup complete!"
echo "================================"
echo "All dependencies cached. Run 'run.sh' during defense to deploy."
