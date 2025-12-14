#!/bin/bash
set -eux

echo "================================"
echo "Installing VirtualBox"
echo "================================"

# Add VirtualBox GPG key
wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg

# Add VirtualBox repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | tee /etc/apt/sources.list.d/virtualbox.list

apt-get update

# Install VirtualBox
apt-get install -y virtualbox-7.0

# Add iot user to vboxusers group
usermod -aG vboxusers iot

echo "================================"
echo "Installing Vagrant"
echo "================================"

# Download and install Vagrant
VAGRANT_VERSION="2.4.1"
wget https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_amd64.deb
dpkg -i vagrant_${VAGRANT_VERSION}-1_amd64.deb
rm vagrant_${VAGRANT_VERSION}-1_amd64.deb

# Verify installations
vboxmanage --version
vagrant --version

echo "================================"
echo "VirtualBox and Vagrant installation complete"
echo "================================"
