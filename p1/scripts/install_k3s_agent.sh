#!/usr/bin/env bash
set -euo pipefail


SERVER_IP=$1:-"192.168.56.110"
TOKEN_FILE=/vagrant/k3s_node_token


# Wait for the server to place the token in the shared folder
for i in {1..60}; do
if [[ -s "$TOKEN_FILE" ]]; then break; fi
echo "[agent] waiting for server token... ($i)"; sleep 2
done

K3S_URL="https://${SERVER_IP}:6443"
K3S_TOKEN=$(cat "$TOKEN_FILE")


curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -


# Give it a moment to register
sleep 8
systemctl status k3s-agent --no-pager || true