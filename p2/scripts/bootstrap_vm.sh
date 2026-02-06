#!/usr/bin/env bash
set -euo pipefail

VM_IP="${1:-192.168.56.110}"

export DEBIAN_FRONTEND=noninteractive

# --- basics (fast if already installed) ---
apt-get update -y
apt-get install -y curl jq htop vim net-tools ca-certificates conntrack socat

# --- sysctls for k8s ---
cat >/etc/sysctl.d/99-k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
EOF
modprobe br_netfilter || true
sysctl --system

# --- small swap so the node doesn’t thrash ---
if ! swapon --show | grep -q '^'; then
  fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

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
# Ensure kubeconfig points to our VM IP (not 127.0.0.1)
sed -i "s#127\.0\.0\.1#${VM_IP}#g" /home/vagrant/.kube/config

# --- wait for API to be responsive & node ready ---
echo "[wait] Kubernetes API…"
until kubectl --request-timeout=5s get --raw=/readyz >/dev/null 2>&1; do sleep 2; done

echo "[wait] Node Ready…"
until kubectl get nodes 2>/dev/null | grep -q ' Ready '; do sleep 2; done

wait_deploy() {
  local ns="$1" name="$2" appear_timeout="${3:-240}" rollout_timeout="${4:-180}"

  echo "[wait] ${ns}/${name} deployment to appear…"
  for _ in $(seq 1 "$appear_timeout"); do
    if kubectl -n "$ns" get deploy "$name" >/dev/null 2>&1; then
      echo "[wait] ${ns}/${name} rollout…"
      kubectl -n "$ns" rollout status "deploy/${name}" --timeout="${rollout_timeout}s" && return 0
      break
    fi
    sleep 2
  done
  echo "[warn] ${ns}/${name} not found or not ready yet; continuing."
  return 0
}

# these are best-effort waits; don't make provisioning fail on a slow first boot
wait_deploy kube-system coredns 300 180 || true
wait_deploy kube-system traefik 420 240 || true

# --- apply app manifest ---
echo "[apply] p2-app.yaml…"
# Copy from inline heredoc since /vagrant is not available
kubectl apply -f /tmp/p2-app.yaml

# --- wait for all 3 apps to be ready ---
echo "[wait] app1 deployment…"
kubectl -n iot rollout status deploy/app1 --timeout=180s
echo "[wait] app2 deployment (3 replicas)…"
kubectl -n iot rollout status deploy/app2 --timeout=180s
echo "[wait] app3 deployment…"
kubectl -n iot rollout status deploy/app3 --timeout=180s

# --- show usage ---
echo
echo "============================================"
echo "Part 2 ready! Test with:"
echo "  curl -H 'Host: app1.com' http://${VM_IP}/"
echo "  curl -H 'Host: app2.com' http://${VM_IP}/"
echo "  curl http://${VM_IP}/          # -> app3 (default)"
echo "============================================"
