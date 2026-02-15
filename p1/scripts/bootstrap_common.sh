#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Prevent apt-daily from grabbing the dpkg lock during provisioning
systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
apt-get install -y curl net-tools

# Raise enp0s3 (NAT) route metric so enp0s8 (host-only) wins later.
# The actual default route via enp0s8 is added at the end of K3s install
# scripts, after all internet downloads are done.
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
