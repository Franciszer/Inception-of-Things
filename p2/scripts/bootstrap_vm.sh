#!/usr/bin/env bash
set -euo pipefail

VM_IP="${1:-192.168.56.110}"

export DEBIAN_FRONTEND=noninteractive

# Prevent apt-daily from grabbing the dpkg lock during provisioning
systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
apt-get install -y curl net-tools

# --- k3s server (traefik & flannel enabled by default) ---
if ! systemctl is-active --quiet k3s; then
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server \
      --node-ip ${VM_IP} \
      --advertise-address ${VM_IP} \
      --tls-san ${VM_IP} \
      --write-kubeconfig-mode=644" \
    sh -
fi

# --- kubeconfig for vagrant user ---
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
sed -i "s#127\.0\.0\.1#${VM_IP}#g" /home/vagrant/.kube/config

# --- wait for API to be responsive & node ready ---
echo "[wait] Kubernetes API..."
until kubectl --request-timeout=5s get --raw=/readyz >/dev/null 2>&1; do sleep 2; done

echo "[wait] Node Ready..."
until kubectl get nodes 2>/dev/null | grep -q ' Ready '; do sleep 2; done

# --- wait for system deployments (best-effort, don't fail provisioning) ---
wait_deploy() {
  local ns="$1" name="$2" timeout="${3:-300}"
  echo "[wait] ${ns}/${name}..."
  for _ in $(seq 1 "$timeout"); do
    if kubectl -n "$ns" get deploy "$name" >/dev/null 2>&1; then
      kubectl -n "$ns" rollout status "deploy/${name}" --timeout="${timeout}s" && return 0
      break
    fi
    sleep 2
  done
  echo "[warn] ${ns}/${name} not ready yet; continuing."
  return 0
}

wait_deploy kube-system coredns 180 || true
wait_deploy kube-system traefik 300 || true

# --- apply app manifest ---
echo "[apply] app.yaml..."
kubectl apply -f /tmp/app.yaml

# --- wait for all 3 apps to be ready ---
echo "[wait] app1 deployment..."
kubectl rollout status deploy/app1 --timeout=180s
echo "[wait] app2 deployment (3 replicas)..."
kubectl rollout status deploy/app2 --timeout=180s
echo "[wait] app3 deployment..."
kubectl rollout status deploy/app3 --timeout=180s

echo
echo "============================================"
echo "Part 2 ready! Test with:"
echo "  curl -H 'Host: app1.com' http://${VM_IP}/"
echo "  curl -H 'Host: app2.com' http://${VM_IP}/"
echo "  curl http://${VM_IP}/          # -> app3 (default)"
echo "============================================"
