#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Prevent apt-daily from grabbing the dpkg lock during provisioning
systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
apt-get install -y curl net-tools

# Make enp0s8 (host-only, required IP) the primary interface so that
# `ip route | grep default` returns it instead of the NAT adapter.
cat > /etc/netplan/99-primary-interface.yaml <<'EOF'
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 200
      dhcp6-overrides:
        route-metric: 200
EOF
chmod 600 /etc/netplan/99-primary-interface.yaml
netplan apply
ip route add default dev enp0s8 metric 50 2>/dev/null || true
