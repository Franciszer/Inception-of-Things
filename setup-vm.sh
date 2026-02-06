#!/bin/bash
# VM Setup Script - Run this inside the Ubuntu VM after creating it manually
# This provisions the VM with all required dependencies for IoT evaluation

set -euo pipefail

echo "================================"
echo "IoT Evaluation VM Setup"
echo "================================"

# Update system
echo "Updating system..."
sudo apt update
sudo apt upgrade -y

# Install base dependencies
echo "Installing base dependencies..."
sudo apt install -y \
    git \
    curl \
    wget \
    vim \
    net-tools \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
echo "Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    echo "✓ Docker installed"
else
    echo "✓ Docker already installed"
fi

# Install VirtualBox
echo "Installing VirtualBox..."
if ! command -v VBoxManage &>/dev/null; then
    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
    echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
    sudo apt update
    sudo apt install -y virtualbox-7.0
    echo "✓ VirtualBox installed"
else
    echo "✓ VirtualBox already installed"
fi

# Install Vagrant
echo "Installing Vagrant..."
if ! command -v vagrant &>/dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt install -y vagrant
    echo "✓ Vagrant installed"
else
    echo "✓ Vagrant already installed"
fi

# Install kubectl
echo "Installing kubectl..."
if ! command -v kubectl &>/dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "✓ kubectl installed"
else
    echo "✓ kubectl already installed"
fi

# Install k3d
echo "Installing k3d..."
if ! command -v k3d &>/dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    echo "✓ k3d installed"
else
    echo "✓ k3d already installed"
fi

# Install Helm
echo "Installing Helm..."
if ! command -v helm &>/dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✓ Helm installed"
else
    echo "✓ Helm already installed"
fi

# Clone the IoT repository
echo "Cloning Inception-of-Things repository..."
if [ ! -d "$HOME/Inception-of-Things" ]; then
    git clone -b frthierr-dev https://github.com/Franciszer/Inception-of-Things.git "$HOME/Inception-of-Things"
    echo "✓ Repository cloned"
else
    echo "✓ Repository already exists"
    cd "$HOME/Inception-of-Things"
    git pull
fi

echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo ""
echo "IMPORTANT: Log out and log back in for Docker group changes to take effect!"
echo ""
echo "To test the parts:"
echo "  cd ~/Inception-of-Things/p1 && vagrant up"
echo "  cd ~/Inception-of-Things/p2 && vagrant up"
echo "  cd ~/Inception-of-Things/p3 && ./run.sh"
echo "  cd ~/Inception-of-Things/bonus && ./run.sh"
echo ""
echo "When ready to export VM:"
echo "  1. Clean up: vagrant destroy -f (in p1, p2)"
echo "  2. Shutdown VM"
echo "  3. From host: VBoxManage export <vm-name> -o iot-eval.ova"
