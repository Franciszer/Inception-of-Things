#!/bin/bash
# Deploy ArgoCD in K3d, watching a public GitHub repo.  Run as normal user (not root).
#
# What this script does:
#   1. Tears down any previous cluster  (clean.sh)
#   2. Creates a K3d cluster (Kubernetes-in-Docker via K3s)
#   3. Creates the 2 required namespaces: argocd and dev
#   4. Installs ArgoCD (GitOps controller) into the argocd namespace
#   5. Applies the ArgoCD Application that watches the GitHub config repo
#   6. Waits for the wil-playground app to come up in the dev namespace
#
# Architecture:
#   VM (Docker daemon)
#   └── K3d cluster "iot"  (single server node)
#       ├── argocd namespace  →  ArgoCD pods (watches GitHub)
#       └── dev namespace     →  wil-playground pod (deployed by ArgoCD)
set -euo pipefail

# Resolve the directory this script lives in (for finding confs/)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER=iot

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }
die()  { echo -e "${RED}>>>${NC} $*" >&2; exit 1; }

# Sanity checks — make sure we have the tools we need
[ "$EUID" -ne 0 ] || die "Do not run as root"
for cmd in docker k3d kubectl; do command -v $cmd >/dev/null || die "$cmd not found"; done
docker info >/dev/null 2>&1 || die "Docker not running"

# Remove any previous cluster
"$DIR/clean.sh" 2>/dev/null || true

# ── K3d cluster ──────────────────────────────────────────────────────
# Creates a single-node K3s cluster running as Docker containers.
#   --servers 1 --agents 0  : 1 server node, no worker nodes (saves RAM)
#   -p "8888:30000@server:0": forward host:8888 → NodePort 30000 (the app)
#   --disable=traefik       : we use NodePort, not Ingress — saves resources
info "Creating K3d cluster..."
k3d cluster create $CLUSTER \
  --servers 1 --agents 0 \
  -p "8888:30000@server:0" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# Subject requires these 2 namespaces: argocd and dev
info "Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev

# ── ArgoCD ───────────────────────────────────────────────────────────
# ArgoCD is a GitOps controller: it watches a git repo and keeps the
# cluster in sync with whatever manifests are in that repo.
# --server-side is needed because the applicationsets CRD exceeds the
# 256KB annotation limit that client-side apply uses.
info "Installing ArgoCD..."
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 15
kubectl wait --for=condition=Available deploy --all -n argocd --timeout=300s

# Speed up ArgoCD reconciliation from default 3 min to 10 seconds.
# This controls how often ArgoCD polls the git repo for changes.
# Makes the v1→v2 demo much snappier during eval.
info "Setting ArgoCD reconciliation to 10s..."
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"timeout.reconciliation":"10s"}}'
# Restart the application controller to pick up the new setting
kubectl rollout restart statefulset argocd-application-controller -n argocd
sleep 5
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=120s
info "ArgoCD ready"

# ── ArgoCD Application ──────────────────────────────────────────────
# The Application resource tells ArgoCD: "watch this GitHub repo and
# deploy whatever manifests you find into the dev namespace."
# Unlike the bonus (which uses a local GitLab), P3 points directly at
# a public GitHub repo — no IP substitution needed.
info "Applying ArgoCD Application..."
kubectl apply -f "$DIR/confs/argocd/app.yaml"
sleep 15
# Wait for ArgoCD to sync and the app pod to come up
kubectl wait --for=condition=Available deploy/wil-playground -n dev --timeout=120s

# ── Print access info ────────────────────────────────────────────────
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

cat <<EOF

===== P3 ready =====

  App:     curl http://localhost:8888
  ArgoCD:  kubectl port-forward svc/argocd-server -n argocd 8080:443 &
           https://localhost:8080  (admin / $ARGOCD_PASS)

  v1 -> v2:
    In the GitHub repo (Franciszer/frthierr-iot-config):
    Edit deployment.yaml, change wil42/playground:v1 to v2, commit+push.
    ArgoCD will auto-sync within ~10 seconds.

========================
EOF
