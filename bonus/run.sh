#!/bin/bash
# Deploy GitLab CE + ArgoCD in K3d.  Run as normal user (not root).
#
# What this script does:
#   1. Tears down any previous cluster/gitlab  (clean.sh)
#   2. Creates a K3d cluster (Kubernetes-in-Docker via K3s)
#   3. Creates the 3 required namespaces: argocd, dev, gitlab
#   4. Installs ArgoCD (GitOps controller) into the argocd namespace
#   5. Starts a standalone GitLab CE Docker container on the same
#      Docker network as K3d, so ArgoCD pods can reach it by IP
#   6. Creates a GitLab repo and pushes the v1 deployment manifests
#   7. Tells ArgoCD to watch that repo and deploy into the dev namespace
#
# Architecture:
#   VM (Docker daemon)
#   ├── k3d-bonus-server-0   ← K3d node (container)
#   │   ├── ArgoCD pods      ← watches GitLab repo
#   │   └── wil-playground   ← deployed by ArgoCD
#   └── gitlab-ce            ← standalone container, same Docker network
set -euo pipefail

# Resolve the directory this script lives in (for finding confs/)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER=bonus
GITLAB=gitlab-ce
GITLAB_PORT=8181           # host port mapped to GitLab's port 80
GITLAB_PASS=password42     # root password for GitLab web UI + git push

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}>>>${NC} $*"; }
die()  { echo -e "${RED}>>>${NC} $*" >&2; exit 1; }

# Sanity checks
[ "$EUID" -ne 0 ] || die "Do not run as root"
for cmd in docker k3d kubectl argocd; do command -v $cmd >/dev/null || die "$cmd not found"; done
docker info >/dev/null 2>&1 || die "Docker not running"

# Remove any previous cluster + gitlab container
"$DIR/clean.sh" 2>/dev/null || true

# ── K3d cluster ──────────────────────────────────────────────────────
# Creates a single-node K3s cluster running as Docker containers.
#   --servers 1 --agents 0  : 1 server node, no worker nodes (saves RAM)
#   -p "8888:30000@server:0": forward host:8888 → NodePort 30000 (the app)
#   -p "8080:30080@server:0": forward host:8080 → NodePort 30080 (ArgoCD UI)
#   --disable=traefik       : we use NodePort, not Ingress — saves resources
info "Creating K3d cluster..."
k3d cluster create $CLUSTER \
  --servers 1 --agents 0 \
  -p "8888:30000@server:0" \
  -p "8080:30080@server:0" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait
kubectl wait --for=condition=Ready nodes --all --timeout=60s

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

# Expose ArgoCD UI on NodePort 30080 (mapped to host:8080 by K3d).
# The default argocd-server service is ClusterIP — we switch it to
# NodePort so the evaluator can open it in a browser without running
# kubectl port-forward.
kubectl patch svc argocd-server -n argocd -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {"port": 80, "nodePort": 30080},
      {"port": 443, "nodePort": 30443}
    ]
  }
}'

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
  timeout 10 argocd login localhost:8080 --username admin \
    --password "$INITIAL_PASS" --insecure --plaintext 2>/dev/null && break
  echo -n "."; sleep 5
done
echo
argocd account update-password --account frthierr \
  --new-password password42 --current-password "$INITIAL_PASS"

# ── GitLab CE ────────────────────────────────────────────────────────
# GitLab runs as a standalone Docker container (NOT inside K3d).
# Why not inside K3d?  The Helm chart needs 6-8GB RAM — won't fit in
# our 8GB VM alongside K3d + ArgoCD.
#
# --network k3d-$CLUSTER : puts GitLab on the same Docker network as
#   the K3d nodes, so ArgoCD pods can reach GitLab by its container IP
#   (e.g. 172.18.0.x) without any port forwarding.
# -p 8181:80             : also expose GitLab on the host so we can
#   access the web UI and git clone from the VM itself.
# --memory 3g            : cap RAM so it doesn't starve the cluster.
#
# GITLAB_OMNIBUS_CONFIG tunes GitLab for low resources:
#   external_url          : sets the server name for nginx
#   listen_https=false    : no TLS, keeps it simple
#   prometheus=false      : saves ~200MB RAM
#   sidekiq concurrency=5 : fewer background workers
#   puma workers=0        : single-process mode (less RAM)
info "Starting GitLab CE on port $GITLAB_PORT..."
docker run -d --name $GITLAB --network k3d-$CLUSTER \
  -p ${GITLAB_PORT}:80 --shm-size 256m --memory 3g \
  -e GITLAB_OMNIBUS_CONFIG="
    external_url 'http://$GITLAB';
    nginx['listen_port'] = 80;
    nginx['listen_https'] = false;
    gitlab_rails['initial_root_password'] = '$GITLAB_PASS';
    prometheus_monitoring['enable'] = false;
    sidekiq['max_concurrency'] = 5;
    puma['worker_processes'] = 0;" \
  gitlab/gitlab-ce:latest

# Get GitLab's IP on the k3d Docker network — this is the address
# ArgoCD will use to reach the git repo (not localhost, since ArgoCD
# runs inside a container).
GITLAB_IP=$(docker inspect -f \
  "{{(index .NetworkSettings.Networks \"k3d-$CLUSTER\").IPAddress}}" $GITLAB)
info "GitLab IP on k3d network: $GITLAB_IP"

# GitLab takes 3-5 minutes to initialize all services.
# We poll Docker's built-in health check (not HTTP, because nginx's
# server_name is "gitlab-ce" and won't match requests to "localhost").
info "Waiting for GitLab (3-5 min)..."
SECONDS=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' $GITLAB 2>/dev/null)" = "healthy" ]; do
  (( SECONDS > 600 )) && die "GitLab not healthy after 10 min"
  echo -n "."; sleep 10
done
echo
info "GitLab healthy (${SECONDS}s)"

# GitLab's API rejects HTTP basic auth (401), so we create a personal
# access token via the Rails console. This is the only way to get an
# API token non-interactively.
info "Creating GitLab API token..."
GITLAB_TOKEN=$(docker exec $GITLAB gitlab-rails runner "
  u = User.find_by_username('root')
  t = u.personal_access_tokens.create!(
    name: 'setup', scopes: ['api','read_repository','write_repository'],
    expires_at: 365.days.from_now)
  print t.token" 2>/dev/null)
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
# We sed-replace GITLAB_HOST with the actual container IP so ArgoCD
# can reach GitLab over the Docker network.
info "Applying ArgoCD Application..."
sed "s|GITLAB_HOST|${GITLAB_IP}|" "$DIR/confs/argocd/app.yaml" | kubectl apply -f -
sleep 15
# Wait for ArgoCD to sync and the app pod to come up
kubectl wait --for=condition=Available deploy/wil-playground -n dev --timeout=120s

# ── Print access info ────────────────────────────────────────────────
cat <<EOF

===== Bonus ready =====

  App:     curl http://localhost:8888
  GitLab:  http://localhost:${GITLAB_PORT}  (root / $GITLAB_PASS)
  ArgoCD:  http://localhost:8080  (frthierr / password42)

  v1 -> v2:
    git clone http://root:${GITLAB_PASS}@localhost:${GITLAB_PORT}/root/iot-config.git /tmp/iot-config
    cd /tmp/iot-config
    sed -i 's/playground:v1/playground:v2/' deployment.yaml
    git commit -am 'v2' && git push http://root:${GITLAB_PASS}@localhost:${GITLAB_PORT}/root/iot-config.git main

========================
EOF
