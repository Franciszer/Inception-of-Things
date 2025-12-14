#!/bin/bash
set -eux

echo "================================"
echo "Installing kubectl"
echo "================================"

# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

# Verify kubectl
kubectl version --client

echo "================================"
echo "Installing Helm"
echo "================================"

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Verify Helm
helm version

echo "================================"
echo "Installing K3d"
echo "================================"

# Install K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify K3d
k3d --version

echo "================================"
echo "Installing K3s (binary only for p1/p2)"
echo "================================"

# Download K3s binary for later use in Vagrant VMs
curl -sfL https://get.k3s.io > /home/iot/k3s-install.sh
chmod +x /home/iot/k3s-install.sh
chown iot:iot /home/iot/k3s-install.sh

echo "================================"
echo "Kubernetes tools installation complete"
echo "================================"
