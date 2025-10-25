#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="${1:-192.168.56.110}"
WORKER_IP="${2:-192.168.56.111}"
TOKEN_FILE=/vagrant/k3s_node_token

# Wait up to ~2 minutes for the token to appear & be non-empty
for i in {1..60}; do
  if [[ -s "$TOKEN_FILE" ]]; then break; fi
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
