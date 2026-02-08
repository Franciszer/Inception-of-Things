#!/bin/bash
set -euo pipefail

OK='\033[0;32m'; KO='\033[0;31m'; NC='\033[0m'
ERRORS=0
pass() { echo -e "  ${OK}OK${NC}  $*"; }
fail() { echo -e "  ${KO}FAIL${NC} $*"; ERRORS=$((ERRORS + 1)); }

echo "=== Bonus tests ==="

kubectl get nodes           >/dev/null 2>&1 && pass "cluster up"          || fail "cluster down"
kubectl get ns argocd       >/dev/null 2>&1 && pass "ns argocd"           || fail "ns argocd missing"
kubectl get ns dev          >/dev/null 2>&1 && pass "ns dev"              || fail "ns dev missing"
kubectl get ns gitlab       >/dev/null 2>&1 && pass "ns gitlab"           || fail "ns gitlab missing"

N=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c Running || echo 0)
[ "$N" -ge 5 ]                                && pass "argocd $N pods"    || fail "argocd only $N pods"

docker ps --format '{{.Names}}' | grep -qF gitlab-ce \
                                               && pass "gitlab running"   || fail "gitlab not running"
[ "$(docker inspect -f '{{.State.Health.Status}}' gitlab-ce 2>/dev/null)" = "healthy" ] \
                                               && pass "gitlab healthy"   || fail "gitlab unhealthy"

kubectl get pods -n dev --no-headers 2>/dev/null | grep -q Running \
                                               && pass "app pod running"  || fail "no app pod"

R=$(curl -sf http://localhost:8888 2>/dev/null || true)
echo "$R" | grep -qF '"v1"' || echo "$R" | grep -qF '"v2"' \
                                               && pass "app responds: $R" || fail "bad response: $R"

kubectl get app wil-playground -n argocd --no-headers 2>/dev/null | grep -q Synced \
                                               && pass "argocd synced"    || fail "argocd not synced"

echo
[ "$ERRORS" -eq 0 ] && echo -e "${OK}All passed${NC}" || { echo -e "${KO}${ERRORS} failed${NC}"; exit 1; }
