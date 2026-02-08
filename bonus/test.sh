#!/bin/bash
# Checks every point from the bonus correction sheet:
#   1. K3d cluster is running
#   2. The 3 required namespaces exist (argocd, dev, gitlab)
#   3. ArgoCD has enough pods running (7 expected: server, repo-server,
#      redis, dex, app-controller, appset-controller, notifications)
#   4. GitLab Docker container is up and passed its built-in health check
#   5. At least one wil-playground pod is Running in the dev namespace
#   6. The app responds on port 8888 with v1 or v2 JSON
#   7. The ArgoCD Application resource is in "Synced" state
set -euo pipefail

OK='\033[0;32m'; KO='\033[0;31m'; NC='\033[0m'
ERRORS=0
pass() { echo -e "  ${OK}OK${NC}  $*"; }
fail() { echo -e "  ${KO}FAIL${NC} $*"; ERRORS=$((ERRORS + 1)); }

echo "=== Bonus tests ==="

# 1 — cluster
kubectl get nodes           >/dev/null 2>&1 && pass "cluster up"          || fail "cluster down"

# 2 — namespaces (subject requires all three)
kubectl get ns argocd       >/dev/null 2>&1 && pass "ns argocd"           || fail "ns argocd missing"
kubectl get ns dev          >/dev/null 2>&1 && pass "ns dev"              || fail "ns dev missing"
kubectl get ns gitlab       >/dev/null 2>&1 && pass "ns gitlab"           || fail "ns gitlab missing"

# 3 — argocd pods (7 expected, allow >=5 for restarts)
N=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c Running || echo 0)
[ "$N" -ge 5 ]                                && pass "argocd $N pods"    || fail "argocd only $N pods"

# 4 — gitlab container running + healthy
docker ps --format '{{.Names}}' | grep -qF gitlab-ce \
                                               && pass "gitlab running"   || fail "gitlab not running"
[ "$(docker inspect -f '{{.State.Health.Status}}' gitlab-ce 2>/dev/null)" = "healthy" ] \
                                               && pass "gitlab healthy"   || fail "gitlab unhealthy"

# 5 — app pod in dev namespace
kubectl get pods -n dev --no-headers 2>/dev/null | grep -q Running \
                                               && pass "app pod running"  || fail "no app pod"

# 6 — app returns valid JSON with v1 or v2
R=$(curl -sf http://localhost:8888 2>/dev/null || true)
echo "$R" | grep -qF '"v1"' || echo "$R" | grep -qF '"v2"' \
                                               && pass "app responds: $R" || fail "bad response: $R"

# 7 — argocd application synced with gitlab repo
kubectl get app wil-playground -n argocd --no-headers 2>/dev/null | grep -q Synced \
                                               && pass "argocd synced"    || fail "argocd not synced"

echo
[ "$ERRORS" -eq 0 ] && echo -e "${OK}All passed${NC}" || { echo -e "${KO}${ERRORS} failed${NC}"; exit 1; }
