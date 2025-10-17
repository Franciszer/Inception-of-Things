#!/bin/bash


mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts

# Wait for the server to be fully up and running and token to be available
MAX_RETRIES=10
RETRY_DELAY=6
for i in $(seq 1 $MAX_RETRIES); do
  TOKEN=$(ssh -o StrictHostKeyChecking=no vagrant@192.168.56.110 'sudo cat /var/lib/rancher/k3s/server/node-token' 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    echo "[INFO] Successfully retrieved K3s token."
    break
  else
    echo "[WARN] Could not retrieve K3s token, retrying in $RETRY_DELAY seconds... ($i/$MAX_RETRIES)"
    sleep $RETRY_DELAY
  fi
done

if [ -z "$TOKEN" ]; then
  echo "[ERROR] Failed to retrieve K3s token from server after $MAX_RETRIES attempts. Exiting."
  exit 1
fi

echo "[INFO] Installing K3s agent with token: $TOKEN"
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent --node-name=ychibaniSW
