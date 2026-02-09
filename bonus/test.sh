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
#   8. ArgoCD UI accessible via browser on port 8080
#   9. ArgoCD selfHeal: manually break the deployment, verify ArgoCD fixes it
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

# 8 — argocd UI accessible via browser (correction item: "accessible via web browser")
#     We curl the ArgoCD login page and check for a known string.
ARGOCD_UI=$(curl -sf http://localhost:8080 2>/dev/null || true)
echo "$ARGOCD_UI" | grep -qi "argo" \
                                               && pass "argocd UI on :8080" || fail "argocd UI not accessible on :8080"

# 9 — selfHeal: manually change the deployment's image, verify ArgoCD reverts it.
#     This proves ArgoCD is actively watching and correcting drift.
echo
echo "--- selfHeal test ---"
CURRENT_IMG=$(kubectl get deploy wil-playground -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
if [ -z "$CURRENT_IMG" ]; then
  fail "selfHeal: can't read current image"
else
  # Pick the opposite tag so we don't accidentally match
  if echo "$CURRENT_IMG" | grep -qF ":v1"; then WRONG_IMG="wil42/playground:v2"
  else WRONG_IMG="wil42/playground:v1"; fi
  echo "  patching image to $WRONG_IMG (ArgoCD should revert to $CURRENT_IMG)..."
  kubectl set image deploy/wil-playground -n dev wil-playground="$WRONG_IMG" >/dev/null
  # Wait up to 60s for ArgoCD to detect drift and revert
  HEALED=false
  for _ in $(seq 1 30); do
    sleep 2
    IMG=$(kubectl get deploy wil-playground -n dev \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
    if [ "$IMG" = "$CURRENT_IMG" ]; then HEALED=true; break; fi
  done
  $HEALED && pass "selfHeal works (reverted to $CURRENT_IMG)" \
          || fail "selfHeal failed (still $IMG, expected $CURRENT_IMG)"
fi

echo
[ "$ERRORS" -eq 0 ] && echo -e "${OK}All passed${NC}" || { echo -e "${KO}${ERRORS} failed${NC}"; exit 1; }
