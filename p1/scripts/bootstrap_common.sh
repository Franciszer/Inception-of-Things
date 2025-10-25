#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl jq htop vim net-tools ca-certificates conntrack socat

# K8s sysctls
cat >/etc/sysctl.d/99-k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
EOF
modprobe br_netfilter || true
sysctl --system

# Create a small swapfile if none exists (1G is enough for this lab)
if ! swapon --show | grep -q '^'; then
  fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  if ! grep -q '^/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
fi

# k3s likes resolved; ensure resolv.conf is consistent
if systemctl is-active --quiet systemd-resolved; then
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf || true
fi

# Be a good citizen on tiny VMs
systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
