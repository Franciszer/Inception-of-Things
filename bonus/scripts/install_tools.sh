#!/bin/bash
set -eux

###############################################################
# 1. Update system + install prerequisites
###############################################################
apt-get update
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release


###############################################################
# 2. Install Docker (compatible with Ubuntu 20.04)
###############################################################

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg
gpg --batch --yes --dearmor /tmp/docker.gpg
mv /tmp/docker.gpg.gpg /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

# Install Docker packages known to work on focal
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable + start Docker
systemctl enable docker
systemctl start docker

# Add vagrant user to docker group
usermod -aG docker vagrant


###############################################################
# 3. Install kubectl (stable, safe download)
###############################################################

# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Ensure download succeeded
if [ ! -s kubectl ]; then
  echo "ERROR: kubectl download failed!"
  exit 1
fi

# Install kubectl binary
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl


###############################################################
# 4. Install Helm
###############################################################
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash


###############################################################
# 5. Ensure PATH contains /usr/local/bin (for non-interactive shells)
###############################################################
echo 'export PATH=$PATH:/usr/local/bin' >> /etc/profile
