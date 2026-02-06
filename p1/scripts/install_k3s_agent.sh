#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="${1:-192.168.56.110}"
WORKER_IP="${2:-192.168.56.111}"
TOKEN_FILE=/tmp/k3s_node_token

# Fetch token from server via SCP
echo "[agent] Fetching K3s token from server via SCP..."
for i in {1..60}; do
  if scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@${SERVER_IP}:/tmp/k3s_node_token "$TOKEN_FILE" 2>/dev/null && [[ -s "$TOKEN_FILE" ]]; then
    echo "[agent] Token received successfully"
    break
  fi
  echo "[agent] waiting for server token... ($i)"; sleep 2
done

K3S_URL="https://${SERVER_IP}:6443"
K3S_TOKEN="$(cat "$TOKEN_FILE")"

# Install agent
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="agent --with-node-id --node-ip ${WORKER_IP}" \
  K3S_URL="$K3S_URL" \
  K3S_TOKEN="$K3S_TOKEN" sh -

# Don't block provisioning forever if systemd is slow
sleep 5
systemctl is-active --quiet k3s-agent || (journalctl -u k3s-agent -n 50 --no-pager || true)
