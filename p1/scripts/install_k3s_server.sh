#!/usr/bin/env bash
set -euo pipefail


# Install k3s server (control plane). This also installs a kubectl shim at /usr/local/bin/kubectl
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -


# Wait for node-token to appear
TOKEN_FILE=/var/lib/rancher/k3s/server/node-token
for i in {1..60}; do
if [[ -s "$TOKEN_FILE" ]]; then break; fi
sleep 2
done


# Copy token to the shared folder for the worker to consume
cp "$TOKEN_FILE" /vagrant/k3s_node_token
chmod 0644 /vagrant/k3s_node_token


# Prepare kubeconfig for the vagrant user and point it to the server IP
KCFG_SRC=/etc/rancher/k3s/k3s.yaml
KCFG_DST=/home/vagrant/.kube/config


# Replace default 127.0.0.1 with the host-only IP so kubectl works from the server VM
SERVER_IP='192.168.56.110'
mkdir -p /home/vagrant/.kube
cp "$KCFG_SRC" "$KCFG_DST"
sed -i "s/127.0.0.1/$SERVER_IP/g" "$KCFG_DST"
chown -R vagrant:vagrant /home/vagrant/.kube


# Readiness probe
for i in {1..30}; do
  kubectl get nodes 2>/dev/null | grep -q ' Ready ' && break
  sleep 2
done

kubectl get nodes -o wide || true   