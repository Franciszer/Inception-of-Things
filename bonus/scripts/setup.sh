#!/bin/bash
# Bonus setup: GitLab CE + ArgoCD in K3d
# Run on iot-eval-vm as user frthierr (not root)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(dirname "$SCRIPT_DIR")"

CLUSTER_NAME="iot"
GITLAB_CONTAINER="gitlab-ce"
GITLAB_PORT=8181
GITLAB_PASSWORD="password42"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Preflight ──────────────────────────────────────────────
[ "$EUID" -ne 0 ] || die "Do not run as root"
command -v docker  >/dev/null || die "docker not found"
command -v k3d     >/dev/null || die "k3d not found"
command -v kubectl >/dev/null || die "kubectl not found"
docker info >/dev/null 2>&1  || die "Docker daemon not running (or user not in docker group)"

# ── Cleanup previous run ──────────────────────────────────
info "Cleaning up previous deployment..."
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true
docker rm -f "$GITLAB_CONTAINER" 2>/dev/null || true

# ══════════════════════════════════════════════════════════
# 1. Create K3d cluster
# ══════════════════════════════════════════════════════════
info "Creating K3d cluster '$CLUSTER_NAME'..."
k3d cluster create "$CLUSTER_NAME" \
  --servers 1 \
  --agents 0 \
  -p "8888:30000@server:0" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait

kubectl wait --for=condition=Ready nodes --all --timeout=60s
info "Cluster ready"

# ══════════════════════════════════════════════════════════
# 2. Create namespaces
# ══════════════════════════════════════════════════════════
info "Creating namespaces: argocd, dev, gitlab"
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

# ══════════════════════════════════════════════════════════
# 3. Install ArgoCD
# ══════════════════════════════════════════════════════════
info "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

info "Waiting for ArgoCD to be ready (~2 min)..."
sleep 15
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
info "ArgoCD is ready"

# ══════════════════════════════════════════════════════════
# 4. Start GitLab CE container
# ══════════════════════════════════════════════════════════
info "Starting GitLab CE on port $GITLAB_PORT..."
docker run -d \
  --name "$GITLAB_CONTAINER" \
  --network "k3d-${CLUSTER_NAME}" \
  -p "${GITLAB_PORT}:80" \
  --shm-size 256m \
  --memory 3g \
  -e GITLAB_OMNIBUS_CONFIG="
    external_url 'http://${GITLAB_CONTAINER}';
    nginx['listen_port'] = 80;
    nginx['listen_https'] = false;
    gitlab_rails['initial_root_password'] = '${GITLAB_PASSWORD}';
    prometheus_monitoring['enable'] = false;
    sidekiq['max_concurrency'] = 5;
    puma['worker_processes'] = 0;
  " \
  gitlab/gitlab-ce:latest

GITLAB_IP=$(docker inspect -f "{{(index .NetworkSettings.Networks \"k3d-${CLUSTER_NAME}\").IPAddress}}" "$GITLAB_CONTAINER")
info "GitLab container IP on k3d network: $GITLAB_IP"

# ══════════════════════════════════════════════════════════
# 5. Wait for GitLab to be healthy
# ══════════════════════════════════════════════════════════
info "Waiting for GitLab to be healthy (3-5 min)..."
SECONDS=0
until curl -sf "http://localhost:${GITLAB_PORT}/-/health" >/dev/null 2>&1; do
  if (( SECONDS > 600 )); then
    die "GitLab did not become healthy within 10 minutes"
  fi
  echo -n "."
  sleep 10
done
echo ""
info "GitLab is healthy (took ${SECONDS}s)"

# Extra wait for API readiness
info "Waiting for GitLab API..."
until curl -sf "http://localhost:${GITLAB_PORT}/api/v4/version" -u "root:${GITLAB_PASSWORD}" >/dev/null 2>&1; do
  sleep 5
done
info "GitLab API is ready"

# ══════════════════════════════════════════════════════════
# 6. Create GitLab repo and push manifests
# ══════════════════════════════════════════════════════════
info "Creating GitLab repository 'iot-config'..."
curl -sf --request POST "http://localhost:${GITLAB_PORT}/api/v4/projects" \
  -u "root:${GITLAB_PASSWORD}" \
  --header "Content-Type: application/json" \
  --data '{"name":"iot-config","visibility":"public","initialize_with_readme":true}' >/dev/null

sleep 5  # wait for project initialization

info "Pushing deployment manifests to GitLab..."
WORK=$(mktemp -d)
cd "$WORK"
git clone "http://root:${GITLAB_PASSWORD}@localhost:${GITLAB_PORT}/root/iot-config.git"
cd iot-config
cp "${BONUS_DIR}/confs/dev/deployment.yaml" .
cp "${BONUS_DIR}/confs/dev/service.yaml" .
git add deployment.yaml service.yaml
git config user.email "root@gitlab.local"
git config user.name "root"
git commit -m "Add wil-playground v1 manifests"
git push origin main
cd /tmp
rm -rf "$WORK"
info "Manifests pushed to GitLab"

# ══════════════════════════════════════════════════════════
# 7. Apply ArgoCD Application
# ══════════════════════════════════════════════════════════
info "Applying ArgoCD Application (pointing to GitLab at $GITLAB_IP)..."
sed "s|GITLAB_HOST|${GITLAB_IP}|g" "${BONUS_DIR}/confs/argocd/app.yaml" | kubectl apply -f -

# ══════════════════════════════════════════════════════════
# 8. Wait for app deployment
# ══════════════════════════════════════════════════════════
info "Waiting for wil-playground to deploy in dev namespace..."
sleep 15  # give ArgoCD time to sync
kubectl wait --for=condition=Available deployment/wil-playground -n dev --timeout=120s
info "Application deployed!"

# ══════════════════════════════════════════════════════════
# 9. Summary
# ══════════════════════════════════════════════════════════
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "==========================================="
echo "  Bonus deployment complete!"
echo "==========================================="
echo ""
echo "  App:     curl http://localhost:8888"
echo ""
echo "  GitLab:  http://localhost:${GITLAB_PORT}"
echo "           user: root  pass: ${GITLAB_PASSWORD}"
echo ""
echo "  ArgoCD:  kubectl port-forward svc/argocd-server -n argocd 8080:443 &"
echo "           https://localhost:8080"
echo "           user: admin  pass: ${ARGOCD_PASS}"
echo ""
echo "  Update v1 -> v2:"
echo "    cd /tmp"
echo "    git clone http://root:${GITLAB_PASSWORD}@localhost:${GITLAB_PORT}/root/iot-config.git"
echo "    cd iot-config"
echo "    sed -i 's/playground:v1/playground:v2/' deployment.yaml"
echo "    git commit -am 'Update to v2' && git push"
echo "==========================================="
