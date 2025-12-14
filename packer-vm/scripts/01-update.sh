#!/bin/bash
set -eux

echo "================================"
echo "Updating system packages"
echo "================================"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  git \
  jq \
  htop \
  tree \
  unzip \
  build-essential \
  linux-headers-$(uname -r)

echo "================================"
echo "System update complete"
echo "================================"
