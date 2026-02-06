#!/bin/bash
# Build script - Pre-build and cache all parts for fast evaluation
# This prepares everything but doesn't leave it running

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "IoT Build Script"
echo "Pre-building all parts..."
echo "================================"
echo ""

# Part 1: Pre-cache Vagrant boxes and build VMs
echo ">>> Part 1: K3s and Vagrant"
cd "${SCRIPT_DIR}/p1"
if [ -f "Vagrantfile" ]; then
    echo "  - Adding Vagrant boxes..."
    vagrant box add ubuntu/jammy64 --provider virtualbox 2>/dev/null || echo "    Box already added"

    echo "  - Building VMs..."
    vagrant up

    echo "  - Halting VMs..."
    vagrant halt

    echo "✓ Part 1 ready (run 'vagrant up' to start)"
else
    echo "⚠ Part 1 Vagrantfile not found, skipping"
fi
echo ""

# Part 2: Pre-cache and build
echo ">>> Part 2: K3s and three applications"
cd "${SCRIPT_DIR}/p2"
if [ -f "Vagrantfile" ]; then
    echo "  - Building VM..."
    vagrant up

    echo "  - Halting VM..."
    vagrant halt

    echo "✓ Part 2 ready (run 'vagrant up' to start)"
else
    echo "⚠ Part 2 Vagrantfile not found, skipping"
fi
echo ""

# Part 3: Pre-pull Docker images for K3d
echo ">>> Part 3: K3d and Argo CD"
cd "${SCRIPT_DIR}/p3"
if [ -f "Makefile" ]; then
    echo "  - Pre-pulling K3d images..."
    docker pull rancher/k3s:latest 2>/dev/null || echo "    K3s image pull attempted"
    docker pull ghcr.io/k3d-io/k3d-tools:latest 2>/dev/null || echo "    K3d tools pull attempted"
    docker pull ghcr.io/k3d-io/k3d-proxy:latest 2>/dev/null || echo "    K3d proxy pull attempted"

    echo "  - Pre-pulling ArgoCD images..."
    docker pull quay.io/argoproj/argocd:latest 2>/dev/null || echo "    ArgoCD image pull attempted"

    echo "✓ Part 3 images cached (run 'make' to deploy)"
else
    echo "⚠ Part 3 Makefile not found, skipping"
fi
echo ""

# Bonus: Pre-pull GitLab and ArgoCD images
echo ">>> Bonus: GitLab + ArgoCD CI/CD"
cd "${SCRIPT_DIR}/bonus"
if [ -f "build.sh" ]; then
    echo "  - Pre-pulling GitLab images..."
    docker pull gitlab/gitlab-ce:latest 2>/dev/null || echo "    GitLab image pull attempted"

    echo "  - Pre-pulling other images..."
    docker pull redis:latest 2>/dev/null || echo "    Redis image pull attempted"
    docker pull postgres:latest 2>/dev/null || echo "    Postgres image pull attempted"

    echo "✓ Bonus images cached (run './build.sh' to deploy)"
else
    echo "⚠ Bonus build.sh not found, skipping"
fi
echo ""

echo "================================"
echo "Build Complete!"
echo "================================"
echo ""
echo "All parts are pre-built and cached."
echo "To run each part during evaluation:"
echo ""
echo "  Part 1: cd p1 && vagrant up"
echo "  Part 2: cd p2 && vagrant up"
echo "  Part 3: cd p3 && make"
echo "  Bonus:  cd bonus && ./build.sh"
echo ""
echo "✓ Ready for evaluation!"
echo "================================"
