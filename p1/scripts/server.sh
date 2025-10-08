#!/bin/bash

# Installation of K3s in server mode
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode=644 \
  --node-name=ychibaniS \
  --bind-address=192.168.56.110 \
  --advertise-address=192.168.56.110

# Wait for K3s to start
sleep 10

# Check the status of the K3s service
sudo systemctl status k3s
