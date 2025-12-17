#!/bin/bash
# Bonus Part - Run (execute during defense)
# Creates cluster and deploys all components

set -euo pipefail

echo "================================"
echo "Bonus Part - Deploying GitLab + ArgoCD with K3d"
echo "================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo "ERROR: Do not run this script as root"
   exit 1
fi

# Check prerequisites
echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }
command -v k3d >/dev/null 2>&1 || { echo "ERROR: k3d not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }

# Delete existing cluster if it exists
if k3d cluster list | grep -q bonus-cluster; then
    echo "Deleting existing cluster..."
    k3d cluster delete bonus-cluster
fi

echo "================================"
echo "Creating K3d cluster..."
echo "================================"

k3d cluster create bonus-cluster \
  --servers 1 \
  --agents 2 \
  -p "8080:80@loadbalancer" \
  -p "8081:8081@loadbalancer" \
  -p "8888:30000@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

echo "Waiting for cluster to be ready..."
sleep 10

until kubectl get nodes >/dev/null 2>&1; do
    echo "Waiting for kubectl..."
    sleep 3
done

echo "================================"
echo "Creating namespaces..."
echo "================================"

kubectl create namespace argocd || true
kubectl create namespace dev || true
kubectl create namespace gitlab || true

echo "================================"
echo "Installing ArgoCD..."
echo "================================"

# Check if ArgoCD is already installed
if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo "ArgoCD is already installed, skipping installation"
else
    echo "Installing ArgoCD..."
    kubectl apply -n argocd -f ~/Inception-of-Things/bonus/confs/argocd/install.yaml

    echo "Waiting for ArgoCD CRDs..."
    sleep 20
fi

# Apply ArgoCD project and application (idempotent)
echo "Applying ArgoCD configuration..."
kubectl apply -f ~/Inception-of-Things/bonus/confs/argocd/app-project.yaml
kubectl apply -f ~/Inception-of-Things/bonus/confs/dev/argocd-app.yaml

echo "================================"
echo "Installing GitLab via Helm..."
echo "================================"

# Check if GitLab is already installed
if helm list -n gitlab | grep -q gitlab; then
    echo "GitLab is already installed, skipping installation"
else
    echo "Installing GitLab from cached chart..."

    # Use the pre-cached Helm chart
    HELM_CACHE_DIR="${HOME}/.cache/helm-charts"
    GITLAB_CHART=$(ls -t "${HELM_CACHE_DIR}"/gitlab-*.tgz 2>/dev/null | head -1)

    if [ -n "${GITLAB_CHART}" ] && [ -f "${GITLAB_CHART}" ]; then
        echo "Using cached chart: ${GITLAB_CHART}"
        # Install GitLab from local cached chart (no internet download needed)
        helm install gitlab "${GITLAB_CHART}" \
          --namespace gitlab \
          --set global.hosts.domain=localhost \
          --set global.hosts.externalIP=127.0.0.1 \
          --set global.ingress.configureCertmanager=false \
          --set gitlab-runner.install=false \
          --set prometheus.install=false \
          --set global.edition=ce \
          --set certmanager-issuer.email=admin@localhost \
          --timeout 10m
    else
        echo "WARNING: Cached chart not found, falling back to remote installation"
        # Fallback to remote installation if cache is missing
        helm install gitlab gitlab/gitlab \
          --namespace gitlab \
          --set global.hosts.domain=localhost \
          --set global.hosts.externalIP=127.0.0.1 \
          --set global.ingress.configureCertmanager=false \
          --set gitlab-runner.install=false \
          --set prometheus.install=false \
          --set global.edition=ce \
          --set certmanager-issuer.email=admin@localhost \
          --timeout 10m
    fi
fi

echo "================================"
echo "Deployment complete!"
echo "================================"

echo ""
echo "Access Information:"
echo "-------------------"
echo "ArgoCD UI: http://localhost:8080"
echo "  Username: admin"
echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "GitLab UI: http://localhost:8081"
echo "  Username: root"
echo "  Password: kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "Application: http://localhost:8888"
echo ""
echo "Note: GitLab may take 5-10 minutes to fully initialize."
echo "Check status with: kubectl get pods -n gitlab"
