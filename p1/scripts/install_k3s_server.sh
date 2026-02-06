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
# Use /tmp since /vagrant may not be mounted
TOKEN_SRC=/var/lib/rancher/k3s/server/token
TOKEN_DEST=/tmp/k3s_node_token

echo "[server] Waiting for K3s to create token..."
for i in {1..30}; do
  if [ -f "$TOKEN_SRC" ]; then
    cp -f "$TOKEN_SRC" "$TOKEN_DEST"
    chmod 0644 "$TOKEN_DEST"
    echo "[server] Token published to $TOKEN_DEST"
    break
  fi
  echo "[server] waiting for token... ($i)"
  sleep 2
done

if [ ! -f "$TOKEN_DEST" ]; then
  echo "[server] ERROR: Failed to publish token after 60 seconds"
  exit 1
fi

# Start a simple HTTP server to serve the token (for nested VM without SSH)
echo "[server] Starting HTTP server on port 8000 for token sharing..."
cd /tmp && python3 -m http.server 8000 >/dev/null 2>&1 &
echo "[server] Token available at http://${SERVER_IP}:8000/k3s_node_token"

# Make kubectl usable for the vagrant user and point to server IP
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
sed -i "s#127\.0\.0\.1#${SERVER_IP}#g" /home/vagrant/.kube/config

# Quick sanity check (won't block provisioning forever)
timeout 20s bash -c 'until kubectl get nodes >/dev/null 2>&1; do sleep 2; done' || true
