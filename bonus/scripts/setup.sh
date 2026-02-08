#!/bin/bash
# Bonus: deploy GitLab CE + ArgoCD inside a K3d cluster.
# Run as normal user on iot-eval-vm (not root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(dirname "$SCRIPT_DIR")"

CLUSTER=iot
GITLAB=gitlab-ce
GITLAB_PORT=8181
GITLAB_PASS=password42

info() { echo -e "\033[0;32m>>>\033[0m $*"; }
die()  { echo -e "\033[0;31m>>>\033[0m $*" >&2; exit 1; }

# -- preflight --
[ "$EUID" -ne 0 ] || die "Do not run as root"
for cmd in docker k3d kubectl; do command -v $cmd >/dev/null || die "$cmd not found"; done
docker info >/dev/null 2>&1 || die "Docker not running"

# -- tear down previous run --
info "Cleaning up..."
k3d cluster delete $CLUSTER 2>/dev/null || true
docker rm -f $GITLAB 2>/dev/null || true

# -- k3d cluster --
info "Creating K3d cluster..."
k3d cluster create $CLUSTER \
  --servers 1 --agents 0 \
  -p "8888:30000@server:0" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# -- namespaces --
info "Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

# -- argocd --
info "Installing ArgoCD..."
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 15
kubectl wait --for=condition=Available deploy --all -n argocd --timeout=300s
info "ArgoCD ready"

# -- gitlab container --
# Runs outside K3d as a standalone Docker container, but on the same
# Docker network so ArgoCD pods can reach it by IP.
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

GITLAB_IP=$(docker inspect -f \
  "{{(index .NetworkSettings.Networks \"k3d-$CLUSTER\").IPAddress}}" $GITLAB)
info "GitLab IP on k3d network: $GITLAB_IP"

# -- wait for gitlab --
info "Waiting for GitLab (3-5 min)..."
SECONDS=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' $GITLAB 2>/dev/null)" = "healthy" ]; do
  (( SECONDS > 600 )) && die "GitLab not healthy after 10 min"
  echo -n "."; sleep 10
done
echo
info "GitLab healthy (${SECONDS}s)"

# -- gitlab token --
# HTTP basic auth doesn't work for the GitLab API, so we create a
# personal access token via the Rails console.
info "Creating GitLab API token..."
GITLAB_TOKEN=$(docker exec $GITLAB gitlab-rails runner "
  u = User.find_by_username('root')
  t = u.personal_access_tokens.create!(
    name: 'setup', scopes: ['api','read_repository','write_repository'],
    expires_at: 365.days.from_now)
  print t.token" 2>/dev/null)
[ -n "$GITLAB_TOKEN" ] || die "Token creation failed"

# -- seed gitlab repo --
info "Creating repo and pushing manifests..."
curl -sf -X POST "http://localhost:${GITLAB_PORT}/api/v4/projects" \
  -H "Private-Token: $GITLAB_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"iot-config","visibility":"public","initialize_with_readme":true}' >/dev/null
sleep 5

WORK=$(mktemp -d)
git clone "http://oauth2:${GITLAB_TOKEN}@localhost:${GITLAB_PORT}/root/iot-config.git" "$WORK/repo"
cp "$BONUS_DIR/confs/dev/deployment.yaml" "$BONUS_DIR/confs/dev/service.yaml" "$WORK/repo/"
git -C "$WORK/repo" add -A
git -C "$WORK/repo" -c user.email=root@local -c user.name=root commit -m "v1 manifests"
git -C "$WORK/repo" push origin main
rm -rf "$WORK"

# -- argocd application --
# Replace the GITLAB_HOST placeholder with the real container IP.
info "Applying ArgoCD Application..."
sed "s|GITLAB_HOST|${GITLAB_IP}|" "$BONUS_DIR/confs/argocd/app.yaml" | kubectl apply -f -
sleep 15
kubectl wait --for=condition=Available deploy/wil-playground -n dev --timeout=120s

# -- done --
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

cat <<EOF

===== Bonus ready =====

  App:     curl http://localhost:8888
  GitLab:  http://localhost:${GITLAB_PORT}  (root / $GITLAB_PASS)
  ArgoCD:  kubectl port-forward svc/argocd-server -n argocd 8080:443 &
           https://localhost:8080  (admin / $ARGOCD_PASS)

  v1 -> v2:
    git clone http://root:${GITLAB_PASS}@localhost:${GITLAB_PORT}/root/iot-config.git /tmp/iot-config
    cd /tmp/iot-config
    sed -i 's/playground:v1/playground:v2/' deployment.yaml
    git commit -am 'v2' && git push http://root:${GITLAB_PASS}@localhost:${GITLAB_PORT}/root/iot-config.git main

========================
EOF
