#!/bin/bash
set -eux

echo "================================"
echo "Cleaning up for image creation"
echo "================================"

# Clean apt cache
apt-get autoremove -y
apt-get clean -y

# Remove temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;

# Clear bash history
history -c
cat /dev/null > ~/.bash_history

# Clear machine ID for cloning
truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Zero out free space to reduce VM size
dd if=/dev/zero of=/EMPTY bs=1M || true
rm -f /EMPTY

# Sync
sync

echo "================================"
echo "Cleanup complete"
echo "================================"
