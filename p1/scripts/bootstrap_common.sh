#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Prevent apt-daily from grabbing the dpkg lock during provisioning
systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
apt-get install -y curl net-tools
