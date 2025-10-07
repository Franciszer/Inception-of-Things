#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get install -y curl ca-certificates apt-transport-https jq vim


# Ensure vagrant user has a .kube dir ready
mkdir -p /home/vagrant/.kube
chown -R vagrant:vagrant /home/vagrant/.kube
