#!/bin/bash
# Deploy GitLab CE + ArgoCD in K3d.  Run as normal user (not root).
#
# What this script does:
#   1. Tears down any previous cluster  (clean.sh)
#   2. Creates a K3d cluster (Kubernetes-in-Docker via K3s)
#   3. Creates the 3 required namespaces: argocd, dev, gitlab
#   4. Installs ArgoCD (GitOps controller) into the argocd namespace
#   5. Deploys GitLab CE as a Kubernetes Deployment in the gitlab namespace
#   6. Creates a GitLab repo and pushes the v1 deployment manifests
#   7. Tells ArgoCD to watch that repo and deploy into the dev namespace
#
# Architecture:
#   K3d cluster "bonus" (single server node)
#   ├── argocd namespace  →  ArgoCD pods (watches GitLab repo)
#   ├── gitlab namespace  →  GitLab CE pod (git server)
#   └── dev namespace     →  wil-playground pod (deployed by ArgoCD)
#
#   ArgoCD reaches GitLab via Kubernetes DNS:
#     http://gitlab-ce.gitlab.svc.cluster.local
set -euo pipefail

# Resolve the part root (parent of scripts/) for finding confs/
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLUSTER=bonus
GITLAB_PORT=8181           # host port mapped to GitLab's NodePort
GITLAB_PASS=password42     # root password for GitLab web UI + git push
APP_NODEPORT=30000         # NodePort for wil-playground app
ARGOCD_NODEPORT=30080      # NodePort for ArgoCD UI (HTTP)
ARGOCD_NODEPORT_HTTPS=30443 # NodePort for ArgoCD UI (HTTPS, unused in insecure mode)
GITLAB_NODEPORT=30181      # NodePort for GitLab
ARGOCD_HOST_PORT=8080      # host port mapped to ArgoCD NodePort
APP_HOST_PORT=8888         # host port mapped to app NodePort

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }
die()  { echo -e "${RED}>>>${NC} $*" >&2; exit 1; }

# Sanity checks
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
#   -p "${GITLAB_PORT}:${GITLAB_NODEPORT}@server:0": forward host → GitLab
#   --disable=traefik       : we use NodePort, not Ingress — saves resources
info "Creating K3d cluster..."
k3d cluster create $CLUSTER \
  --servers 1 --agents 0 \
  -p "${APP_HOST_PORT}:${APP_NODEPORT}@server:0" \
  -p "${ARGOCD_HOST_PORT}:${ARGOCD_NODEPORT}@server:0" \
  -p "${GITLAB_PORT}:${GITLAB_NODEPORT}@server:0" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# Import pre-pulled images into K3d so pods don't re-download them.
# This only works if build.sh was run first; if not, K3d pulls from
# the registry automatically (just slower).
info "Importing images into K3d..."
k3d image import gitlab/gitlab-ce:latest -c $CLUSTER 2>/dev/null || true
k3d image import wil42/playground:v1 wil42/playground:v2 -c $CLUSTER 2>/dev/null || true

# Subject requires these 3 namespaces: argocd, dev, gitlab
info "Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

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
# v1→v2 demo during eval is quick.
# Also create a local ArgoCD user "frthierr" that can log in via the UI.
info "Configuring ArgoCD..."
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"timeout.reconciliation":"10s","accounts.frthierr":"apiKey, login"}}'

# Give the frthierr account full admin privileges
kubectl patch configmap argocd-rbac-cm -n argocd --type merge \
  -p '{"data":{"policy.csv":"g, frthierr, role:admin"}}'

# Run ArgoCD server in insecure mode (plain HTTP, no TLS redirect).
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
# Retry loop — the server may need a few extra seconds after restart.
# argocd login can hang indefinitely if the server is half-ready, so
# we wrap each attempt with `timeout 10` to force it to fail and retry.
for i in $(seq 1 12); do
  timeout 10 argocd login localhost:${ARGOCD_HOST_PORT} --username admin \
    --password "$INITIAL_PASS" --insecure --plaintext 2>/dev/null && break
  echo -n "."; sleep 5
done
echo
argocd account update-password --account frthierr \
  --new-password password42 --current-password "$INITIAL_PASS"

# ── GitLab CE ────────────────────────────────────────────────────────
# GitLab runs as a Kubernetes Deployment inside the gitlab namespace.
# This is the same gitlab/gitlab-ce:latest Omnibus image, but managed
# by Kubernetes instead of a standalone Docker container.
#
# The Deployment uses a startup probe (httpGet /-/health) that gives
# GitLab up to 10 minutes to boot before Kubernetes considers it failed.
# The Service exposes GitLab on NodePort 30181 (mapped to host:8181).
# ArgoCD reaches GitLab via Kubernetes DNS: gitlab-ce.gitlab.svc.cluster.local
info "Deploying GitLab CE in gitlab namespace..."
kubectl apply -f "$DIR/confs/gitlab/deployment.yaml"
kubectl apply -f "$DIR/confs/gitlab/service.yaml"

# Wait for GitLab to pass its startup probe and become ready.
# This takes 3-5 minutes — the startup probe handles the long boot.
info "Waiting for GitLab..."
kubectl wait --for=condition=Available deploy/gitlab-ce -n gitlab --timeout=600s
info "GitLab ready"

# GitLab's API rejects HTTP basic auth (401), so we create a personal
# access token via the Rails console. This is the only way to get an
# API token non-interactively.
# The startup probe only checks that nginx/workhorse respond — the
# database migrations may still be running. Retry until Rails is ready.
info "Creating GitLab API token..."
GITLAB_POD=$(kubectl get pods -n gitlab -l app=gitlab-ce \
  -o jsonpath='{.items[0].metadata.name}')
GITLAB_TOKEN=""
for i in $(seq 1 30); do
  GITLAB_TOKEN=$(kubectl exec -i -n gitlab "$GITLAB_POD" -- \
    gitlab-rails runner - <<'RUBY' 2>/dev/null
u = User.find_by_username("root")
u.personal_access_tokens.where(name: "setup").destroy_all
t = u.personal_access_tokens.create!(
  name: "setup", scopes: ["api","read_repository","write_repository"],
  expires_at: 365.days.from_now)
print t.token
RUBY
  ) && [ -n "$GITLAB_TOKEN" ] && break
  echo -n "."; sleep 10
done
echo
[ -n "$GITLAB_TOKEN" ] || die "Token creation failed"

# ── Seed the GitLab repo ─────────────────────────────────────────────
# Create a project via the API, then clone it, copy our v1 manifests
# (deployment.yaml + service.yaml) into it, and push.
# This is the repo ArgoCD will watch.
info "Creating repo and pushing manifests..."
curl -sf -X POST "http://localhost:${GITLAB_PORT}/api/v4/projects" \
  -H "Private-Token: $GITLAB_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"iot-config","visibility":"public","initialize_with_readme":true}' >/dev/null
sleep 5

# Clone into a temp dir, copy manifests, commit, push
WORK=$(mktemp -d)
git clone "http://oauth2:${GITLAB_TOKEN}@localhost:${GITLAB_PORT}/root/iot-config.git" "$WORK/repo"
cp "$DIR/confs/dev/deployment.yaml" "$DIR/confs/dev/service.yaml" "$WORK/repo/"
git -C "$WORK/repo" add -A
git -C "$WORK/repo" -c user.email=root@local -c user.name=root commit -m "v1 manifests"
git -C "$WORK/repo" push origin main
rm -rf "$WORK"

# ── ArgoCD Application ───────────────────────────────────────────────
# The Application resource tells ArgoCD: "watch this git repo and
# deploy whatever manifests you find into the dev namespace."
# The repoURL uses Kubernetes DNS (gitlab-ce.gitlab.svc.cluster.local)
# so ArgoCD can reach GitLab directly — no IP substitution needed.
info "Applying ArgoCD Application..."
kubectl apply -f "$DIR/confs/argocd/app.yaml"
sleep 15
# Wait for ArgoCD to sync and the app pod to come up
kubectl wait --for=condition=Available deploy/wil-playground -n dev --timeout=120s

# ── Print access info ────────────────────────────────────────────────
cat <<EOF

===== Bonus ready =====

  App:     curl http://localhost:${APP_HOST_PORT}
  GitLab:  http://localhost:${GITLAB_PORT}  (root / $GITLAB_PASS)
  ArgoCD:  http://localhost:${ARGOCD_HOST_PORT}  (frthierr / password42)

  v1 -> v2:
    git clone http://root:${GITLAB_PASS}@localhost:${GITLAB_PORT}/root/iot-config.git /tmp/iot-config
    cd /tmp/iot-config
    sed -i 's/playground:v1/playground:v2/' deployment.yaml
    git commit -am 'v2' && git push http://root:${GITLAB_PASS}@localhost:${GITLAB_PORT}/root/iot-config.git main

========================
EOF
