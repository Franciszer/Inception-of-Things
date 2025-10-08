#!/bin/bash

# Wait for the server to be fully up and running
sleep 15

# Retrieve the K3s token from the server
TOKEN=$(ssh -o StrictHostKeyChecking=no vagrant@192.168.56.110 'sudo cat /var/lib/rancher/k3s/server/node-token')

# Installation of K3s in worker mode
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent --node-name=ychibaniSW
