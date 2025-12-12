#!/bin/bash
set -eux

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create K3d cluster
k3d cluster create bonus-cluster \
  --servers 1 \
  --agents 2 \
  -p "8888:30000@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

echo "Waiting for Kubernetes API to become ready..."
sleep 15

# Wait until kubectl is responsive
until kubectl get nodes >/dev/null 2>&1; do
    echo "Waiting for kubectl..."
    sleep 3
done

# Namespaces
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

# Install ArgoCD (validation off because CRDs break early apply)
kubectl apply -n argocd -f /vagrant/confs/argocd/install.yaml --validate=false

echo "Waiting 20 seconds for ArgoCD CRDs to settle..."
sleep 20

# Apply project + application (validation off again for consistency)
kubectl apply -f /vagrant/confs/argocd/app-project.yaml --validate=false
kubectl apply -f /vagrant/confs/dev/argocd-app.yaml --validate=false
