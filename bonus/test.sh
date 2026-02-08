#!/bin/bash
# Bonus part — automated validation
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ERRORS=$((ERRORS + 1)); }

ERRORS=0
echo "=== Bonus Part Tests ==="
echo ""

# 1. K3d cluster
if kubectl get nodes >/dev/null 2>&1; then
  pass "K3d cluster is running"
else
  fail "K3d cluster not found"
fi

# 2. Namespaces
for ns in argocd dev gitlab; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    pass "Namespace '$ns' exists"
  else
    fail "Namespace '$ns' not found"
  fi
done

# 3. ArgoCD pods
ARGOCD_RUNNING=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c Running || echo 0)
if [ "$ARGOCD_RUNNING" -ge 5 ]; then
  pass "ArgoCD: $ARGOCD_RUNNING pods running"
else
  fail "ArgoCD: only $ARGOCD_RUNNING pods running (expected >= 5)"
fi

# 4. GitLab container
if docker ps --format '{{.Names}}' | grep -qF gitlab-ce; then
  pass "GitLab container is running"
else
  fail "GitLab container not running"
fi

if [ "$(docker inspect -f '{{.State.Health.Status}}' gitlab-ce 2>/dev/null)" = "healthy" ]; then
  pass "GitLab health check OK (Docker healthy)"
else
  fail "GitLab health check failed"
fi

# 5. App pod in dev namespace
if kubectl get pods -n dev --no-headers 2>/dev/null | grep -q Running; then
  pass "Application pod running in dev namespace"
else
  fail "No running pod in dev namespace"
fi

# 6. App responds
RESPONSE=$(curl -sf http://localhost:8888 2>/dev/null || echo "")
if echo "$RESPONSE" | grep -qF '"v1"'; then
  pass "App returns v1: $RESPONSE"
elif echo "$RESPONSE" | grep -qF '"v2"'; then
  pass "App returns v2: $RESPONSE"
else
  fail "App response unexpected: '$RESPONSE'"
fi

# 7. ArgoCD Application synced
APP_STATUS=$(kubectl get application wil-playground -n argocd --no-headers 2>/dev/null || echo "")
if echo "$APP_STATUS" | grep -q "Synced"; then
  pass "ArgoCD Application is Synced"
else
  fail "ArgoCD Application not synced: $APP_STATUS"
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}$ERRORS test(s) failed${NC}"
  exit 1
fi
