#!/bin/bash





echo "[INFO] Installing K3s in server mode..."
if ! curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode=644 \
  --node-name=ychibaniS \
  --bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110; then
  echo "[ERROR] K3s server installation failed!" >&2
  exit 1
fi

echo "[INFO] Waiting for K3s to start..."
sleep 10

echo "[INFO] Checking K3s service status..."
if ! sudo systemctl is-active --quiet k3s; then
  sudo systemctl status k3s
  echo "[ERROR] K3s service is not active!" >&2
  exit 1
fi

echo "[INFO] K3s server setup completed successfully."
