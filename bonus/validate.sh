#!/bin/bash
# Validation script for IoT Bonus Part
# This script verifies all requirements from the 42 evaluation sheet

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║         IoT Bonus Part - Validation Script                ║${NC}"
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check 1: Configuration files in bonus folder
echo -e "${YELLOW}[1/7]${NC} Checking configuration files in bonus folder..."
if [ -f "Vagrantfile" ] && [ -d "scripts" ] && [ -d "confs" ]; then
    echo -e "${GREEN}✓${NC} Configuration files found"
else
    echo -e "${RED}✗${NC} Missing configuration files"
    exit 1
fi

# Check 2: GitLab is running
echo -e "${YELLOW}[2/7]${NC} Checking GitLab is running..."
GITLAB_STATUS=$(vagrant ssh -- -t 'sudo docker ps | grep gitlab | grep healthy' 2>/dev/null || echo "NOT_RUNNING")
if [[ $GITLAB_STATUS == *"healthy"* ]]; then
    echo -e "${GREEN}✓${NC} GitLab is running and healthy"
else
    echo -e "${RED}✗${NC} GitLab is not running or not healthy"
    exit 1
fi

# Check 3: GitLab repository exists
echo -e "${YELLOW}[3/7]${NC} Checking GitLab repository exists..."
REPO_CHECK=$(vagrant ssh -- -t 'curl -s --header "PRIVATE-TOKEN: iot-automation-token-123" "http://192.168.56.150/api/v4/projects" | grep -o "iot-repo"' 2>/dev/null || echo "")
if [[ $REPO_CHECK == *"iot-repo"* ]]; then
    echo -e "${GREEN}✓${NC} GitLab repository 'iot-repo' exists"
else
    echo -e "${RED}✗${NC} GitLab repository not found"
    exit 1
fi

# Check 4: ArgoCD is using local GitLab
echo -e "${YELLOW}[4/7]${NC} Checking ArgoCD uses local GitLab repository..."
ARGOCD_REPO=$(vagrant ssh -- -t 'kubectl get application bonus-app -n argocd -o yaml 2>/dev/null | grep "repoURL:" | head -1' || echo "")
if [[ $ARGOCD_REPO == *"192.168.56.150"* ]]; then
    echo -e "${GREEN}✓${NC} ArgoCD is using local GitLab (192.168.56.150)"
else
    echo -e "${RED}✗${NC} ArgoCD is not using local GitLab"
    exit 1
fi

# Check 5: ArgoCD application is synced and healthy
echo -e "${YELLOW}[5/7]${NC} Checking ArgoCD application status..."
APP_STATUS=$(vagrant ssh -- -t 'kubectl get application bonus-app -n argocd 2>/dev/null' || echo "")
if [[ $APP_STATUS == *"Synced"* ]] && [[ $APP_STATUS == *"Healthy"* ]]; then
    echo -e "${GREEN}✓${NC} Application is Synced and Healthy"
else
    echo -e "${RED}✗${NC} Application is not Synced or not Healthy"
    echo "$APP_STATUS"
    exit 1
fi

# Check 6: Application is accessible
echo -e "${YELLOW}[6/7]${NC} Checking application is accessible..."
APP_RESPONSE=$(vagrant ssh -- -t 'curl -s http://192.168.56.150:8888 2>/dev/null' || echo "")
if [[ $APP_RESPONSE == *"status"* ]] && [[ $APP_RESPONSE == *"ok"* ]]; then
    CURRENT_VERSION=$(echo "$APP_RESPONSE" | grep -o 'v[0-9]')
    echo -e "${GREEN}✓${NC} Application is accessible - Current version: $CURRENT_VERSION"
else
    echo -e "${RED}✗${NC} Application is not accessible"
    exit 1
fi

# Check 7: Verify complete stack
echo -e "${YELLOW}[7/7]${NC} Verifying complete stack..."
echo "  - Checking K3d cluster..."
NODE_COUNT=$(vagrant ssh -- -t 'kubectl get nodes --no-headers 2>/dev/null | wc -l' || echo "0")
if [ "$NODE_COUNT" -ge 3 ]; then
    echo -e "    ${GREEN}✓${NC} K3d cluster has $NODE_COUNT nodes"
else
    echo -e "    ${RED}✗${NC} K3d cluster issue"
    exit 1
fi

echo "  - Checking ArgoCD pods..."
ARGOCD_PODS=$(vagrant ssh -- -t 'kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l' || echo "0")
if [ "$ARGOCD_PODS" -ge 7 ]; then
    echo -e "    ${GREEN}✓${NC} ArgoCD has $ARGOCD_PODS pods running"
else
    echo -e "    ${RED}✗${NC} ArgoCD pods issue"
    exit 1
fi

echo "  - Checking application pods..."
APP_PODS=$(vagrant ssh -- -t 'kubectl get pods -n dev --no-headers 2>/dev/null | grep Running | wc -l' || echo "0")
if [ "$APP_PODS" -ge 1 ]; then
    echo -e "    ${GREEN}✓${NC} Application has $APP_PODS pod(s) running"
else
    echo -e "    ${RED}✗${NC} Application pods issue"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ALL VALIDATIONS PASSED SUCCESSFULLY!             ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

echo "Summary:"
echo "--------"
echo "✓ GitLab: Running and accessible at http://192.168.56.150"
echo "✓ Repository: iot-repo exists in GitLab"
echo "✓ ArgoCD: Using local GitLab repository"
echo "✓ Application: Synced, Healthy, and accessible"
echo "✓ Infrastructure: K3d cluster with $NODE_COUNT nodes"
echo "✓ Current version: $CURRENT_VERSION"
echo ""

echo "Quick Access:"
echo "-------------"
echo "GitLab:      http://192.168.56.150"
echo "             User: root"
echo "             Pass: c1l1g+YFxHLLLDvGB94X7Mr18zPWHMlzRGeacqJVQoE="
echo ""
echo "Application: http://192.168.56.150:8888"
echo "             Current response: $APP_RESPONSE"
echo ""

echo "Next Steps:"
echo "-----------"
echo "1. Test version change: See EVALUATION_GUIDE.md section 4"
echo "2. Create test repository: See EVALUATION_GUIDE.md section 2"
echo "3. Review complete guide: cat EVALUATION_GUIDE.md"
echo ""
