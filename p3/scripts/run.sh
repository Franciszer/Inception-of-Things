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
#   └── K3d cluster "p3"  (single server node)
#       ├── argocd namespace  →  ArgoCD pods (watches GitHub)
#       └── dev namespace     →  wil-playground pod (deployed by ArgoCD)
set -euo pipefail

# Resolve the part root (parent of scripts/) for finding confs/
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLUSTER=p3
APP_NODEPORT=30000         # NodePort for wil-playground app
ARGOCD_NODEPORT=30080      # NodePort for ArgoCD UI (HTTP)
ARGOCD_NODEPORT_HTTPS=30443 # NodePort for ArgoCD UI (HTTPS, unused in insecure mode)
ARGOCD_HOST_PORT=8080      # host port mapped to ArgoCD NodePort
APP_HOST_PORT=8888         # host port mapped to app NodePort

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }
die()  { echo -e "${RED}>>>${NC} $*" >&2; exit 1; }

# Sanity checks — make sure we have the tools we need
[ "$EUID" -ne 0 ] || die "Do not run as root"
for cmd in docker k3d kubectl argocd; do command -v $cmd >/dev/null || die "$cmd not found"; done
docker info >/dev/null 2>&1 || die "Docker not running"

# Remove any previous cluster
"$DIR/scripts/clean.sh" 2>/dev/null || true

# ── K3d cluster ──────────────────────────────────────────────────────
# Creates a single-node K3s cluster running as Docker containers.
#   --servers 1 --agents 0  : 1 server node, no worker nodes (saves RAM)
#   -p "${APP_HOST_PORT}:${APP_NODEPORT}@server:0": forward host → app
#   -p "${ARGOCD_HOST_PORT}:${ARGOCD_NODEPORT}@server:0": forward host → ArgoCD UI
#   --disable=traefik       : we use NodePort, not Ingress — saves resources
info "Creating K3d cluster..."
k3d cluster create $CLUSTER \
  --servers 1 --agents 0 \
  -p "${APP_HOST_PORT}:${APP_NODEPORT}@server:0" \
  -p "${ARGOCD_HOST_PORT}:${ARGOCD_NODEPORT}@server:0" \
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

# ── ArgoCD configuration ────────────────────────────────────────────
# Speed up reconciliation from default 3 min to 10 seconds so the
# v1→v2 demo during eval is snappy.
# Also create a local ArgoCD user "frthierr" that can log in via the UI.
info "Configuring ArgoCD..."
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"timeout.reconciliation":"10s","accounts.frthierr":"apiKey, login"}}'

# Give the frthierr account full admin privileges
kubectl patch configmap argocd-rbac-cm -n argocd --type merge \
  -p '{"data":{"policy.csv":"g, frthierr, role:admin"}}'

# Run ArgoCD server in insecure mode (plain HTTP, no TLS redirect).
# This lets us expose the UI directly via NodePort without dealing
# with self-signed certificates in the browser.
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# Expose ArgoCD UI on NodePort (mapped to host:${ARGOCD_HOST_PORT} by K3d).
# The default argocd-server service is ClusterIP — we switch it to
# NodePort so the evaluator can open it in a browser without running
# kubectl port-forward.
kubectl patch svc argocd-server -n argocd -p "{
  \"spec\": {
    \"type\": \"NodePort\",
    \"ports\": [
      {\"port\": 80, \"nodePort\": ${ARGOCD_NODEPORT}},
      {\"port\": 443, \"nodePort\": ${ARGOCD_NODEPORT_HTTPS}}
    ]
  }
}"

# Restart to pick up the configmap changes
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-server -n argocd
sleep 5
kubectl wait --for=condition=Available deploy --all -n argocd --timeout=120s
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=120s
info "ArgoCD ready"

# Set the password for the frthierr account using the argocd CLI.
# We log in as admin (with the auto-generated initial password),
# then set frthierr's password to "password42".
INITIAL_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
info "Setting up frthierr account..."
# Retry loop — argocd login hangs if the server is half-ready after
# restart, so we wrap each attempt with timeout 10.
for i in $(seq 1 12); do
  timeout 10 argocd login localhost:${ARGOCD_HOST_PORT} --username admin \
    --password "$INITIAL_PASS" --insecure --plaintext 2>/dev/null && break
  echo -n "."; sleep 5
done
echo
argocd account update-password --account frthierr \
  --new-password password42 --current-password "$INITIAL_PASS"

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
cat <<EOF

===== P3 ready =====

  App:     curl http://localhost:${APP_HOST_PORT}
  ArgoCD:  http://localhost:${ARGOCD_HOST_PORT}  (frthierr / password42)

  v1 -> v2:
    In the GitHub repo (Franciszer/frthierr-iot-config):
    Edit deployment.yaml, change wil42/playground:v1 to v2, commit+push.
    ArgoCD will auto-sync within ~10 seconds.

========================
EOF
