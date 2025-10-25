#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="${1:-192.168.56.110}"

# Install k3s server with explicit IPs
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="
  server
  --node-ip ${SERVER_IP}
  --advertise-address ${SERVER_IP}
  --tls-san ${SERVER_IP}
  --write-kubeconfig-mode=644
" sh -

# Publish the node token for the worker to read
TOKEN_SRC=/var/lib/rancher/k3s/server/token
if [ -f "$TOKEN_SRC" ]; then
  cp -f "$TOKEN_SRC" /vagrant/k3s_node_token
  chmod 0644 /vagrant/k3s_node_token
fi

# Make kubectl usable for the vagrant user and point to server IP
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
sed -i "s#127\.0\.0\.1#${SERVER_IP}#g" /home/vagrant/.kube/config

# Quick sanity check (won't block provisioning forever)
timeout 20s bash -c 'until kubectl get nodes >/dev/null 2>&1; do sleep 2; done' || true
