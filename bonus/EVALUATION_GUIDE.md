# IoT Bonus - Evaluation Guide

This guide follows the exact evaluation criteria from the 42 correction sheet for the bonus part.

## Prerequisites

All commands should be run from the `bonus/` directory:
```bash
cd /home/frthierr/Workspace/Inception-of-Things/bonus
```

## Evaluation Checklist

### 1. Configuration Files in Bonus Folder ✅

Check that configuration files are present:
```bash
ls -la
# Expected: Vagrantfile, scripts/, confs/

ls scripts/
# Expected: install_tools.sh, install_k3d.sh, install_gitlab.sh

ls confs/argocd/
# Expected: install.yaml, app-project.yaml

ls confs/dev/
# Expected: deployment.yaml, service.yaml, argocd-app.yaml
```

**Explanation:**
- `Vagrantfile`: Defines the VM with Docker, kubectl, Helm
- `scripts/`: Installation scripts for tools, k3d cluster, and GitLab
- `confs/argocd/`: ArgoCD installation and project configuration
- `confs/dev/`: Kubernetes manifests and ArgoCD application definition

### 2. Test GitLab Functions Correctly ✅

#### Access GitLab Web UI

**URL**: http://192.168.56.150
**Username**: `root`
**Password**: `c1l1g+YFxHLLLDvGB94X7Mr18zPWHMlzRGeacqJVQoE=`

#### Verify GitLab is Running

```bash
vagrant ssh -- -t 'sudo docker ps | grep gitlab'
# Expected: Container should show status as "healthy"
```

#### Create a New Repository on GitLab (Evaluation Test)

Using the GitLab API:
```bash
vagrant ssh -- -t 'curl -s --header "PRIVATE-TOKEN: iot-automation-token-123" \
  --header "Content-Type: application/json" \
  --data "{\"name\": \"test-repo\", \"visibility\": \"public\"}" \
  --request POST "http://192.168.56.150/api/v4/projects"'
```

Or via Web UI:
1. Navigate to http://192.168.56.150
2. Login with root credentials
3. Click "New project" → "Create blank project"
4. Enter project name: `test-repo`
5. Click "Create project"

#### Add Code to the Repository

```bash
vagrant ssh -- -t 'cd /tmp && rm -rf test-repo && \
  git clone http://root:c1l1g+YFxHLLLDvGB94X7Mr18zPWHMlzRGeacqJVQoE=@192.168.56.150/root/test-repo.git && \
  cd test-repo && \
  echo "# Test Repository" > README.md && \
  git config user.email "root@example.com" && \
  git config user.name "root" && \
  git add . && \
  git commit -m "Initial commit" && \
  git push origin main'
```

#### Verify the Operation Was Successful

```bash
vagrant ssh -- -t 'curl -s --header "PRIVATE-TOKEN: iot-automation-token-123" \
  "http://192.168.56.150/api/v4/projects/root%2Ftest-repo/repository/tree"'
# Expected: Should show README.md in the repository
```

### 3. Part 3 Operations Work with Local GitLab ✅

#### Verify ArgoCD Uses Local GitLab Repository

```bash
vagrant ssh -- -t 'kubectl get application bonus-app -n argocd -o yaml | grep repoURL'
# Expected: repoURL: http://192.168.56.150/root/iot-repo.git
```

**This is the LOCAL GitLab repository, NOT GitHub!**

#### Check Current Application Status

```bash
vagrant ssh -- -t 'kubectl get applications -n argocd'
# Expected: bonus-app   Synced   Healthy

vagrant ssh -- -t 'kubectl get pods -n dev'
# Expected: bonus-app pod running

vagrant ssh -- -t 'kubectl get svc -n dev'
# Expected: bonus-app service on NodePort 30000
```

#### Test Application v1

```bash
vagrant ssh -- -t 'curl -s http://192.168.56.150:8888'
# Expected: {"status":"ok", "message": "v1"}
```

### 4. Demonstrate Version Change with Synchronization ✅

This demonstrates the complete GitOps workflow using the local GitLab repository.

#### Step 1: Check Current Version

```bash
vagrant ssh -- -t 'curl -s http://192.168.56.150:8888'
# Current: {"status":"ok", "message": "v1"}
```

#### Step 2: Update to v2 via GitLab

Clone the repository, change to v2, and push:
```bash
vagrant ssh -- -t 'cd /tmp/iot-repo && \
  git pull && \
  sed -i "s|image: wil42/playground:v1|image: wil42/playground:v2|" dev/deployment.yaml && \
  git add . && \
  git commit -m "Update to v2" && \
  git push origin main'
```

#### Step 3: Verify Git Change Was Pushed to GitLab

```bash
vagrant ssh -- -t 'curl -s --header "PRIVATE-TOKEN: iot-automation-token-123" \
  "http://192.168.56.150/api/v4/projects/root%2Fiot-repo/repository/files/dev%2Fdeployment.yaml?ref=main" | \
  grep -o "wil42/playground:v[0-9]"'
# Expected: wil42/playground:v2
```

#### Step 4: Wait for ArgoCD Auto-Sync (or Manual Sync)

ArgoCD polls every 3 minutes by default. Wait or manually trigger:

**Check ArgoCD detected the change:**
```bash
vagrant ssh -- -t 'kubectl get application bonus-app -n argocd'
# Status may show "OutOfSync" initially, then "Synced"
```

**Manual sync (optional if automatic hasn't happened yet):**
```bash
vagrant ssh -- -t 'kubectl delete application bonus-app -n argocd && \
  kubectl apply -f /vagrant/confs/dev/argocd-app.yaml'
```

#### Step 5: Wait for Pod to Update

```bash
vagrant ssh -- -t 'kubectl get pods -n dev -w'
# Watch for pod termination and recreation with v2 image
# Press Ctrl+C to stop watching
```

#### Step 6: Verify Application is Now v2

```bash
vagrant ssh -- -t 'sleep 30 && curl -s http://192.168.56.150:8888'
# Expected: {"status":"ok", "message": "v2"}
```

#### Step 7: Verify Synchronization Was Successful

```bash
vagrant ssh -- -t 'kubectl describe application bonus-app -n argocd | grep -A 5 "Status:"'
# Expected: Status should show "Synced" and "Healthy"

vagrant ssh -- -t 'kubectl get pods -n dev -o wide'
# Expected: Pod should be running with the v2 image
```

### 5. Complete Workflow Summary

The complete GitOps workflow is:

```
Developer → Push to GitLab (192.168.56.150/root/iot-repo)
          ↓
ArgoCD Polls GitLab (every 3 minutes or manual sync)
          ↓
ArgoCD Detects Change
          ↓
ArgoCD Applies New Manifests to K8s
          ↓
Kubernetes Updates Deployment
          ↓
New Pod Created with Updated Version
          ↓
Application Accessible with New Version
```

## Validation Checklist

For the evaluation to pass, verify:

- [x] Configuration files exist in bonus folder
- [x] GitLab is running and accessible
- [x] Can create new repository on GitLab
- [x] Can add code to GitLab repository
- [x] ArgoCD uses LOCAL GitLab repository (http://192.168.56.150/...)
- [x] Application v1 is accessible
- [x] Can update to v2 by pushing to GitLab
- [x] ArgoCD detects and syncs the change
- [x] Application updates to v2 successfully
- [x] Synchronization completes with no errors

## Quick Verification Commands

```bash
# Check entire stack
vagrant ssh -- -t '
echo "=== K3d Cluster ===" && kubectl get nodes && \
echo -e "\n=== GitLab ===" && sudo docker ps | grep gitlab | grep healthy && \
echo -e "\n=== ArgoCD ===" && kubectl get applications -n argocd && \
echo -e "\n=== Application ===" && kubectl get pods,svc -n dev && \
echo -e "\n=== App Response ===" && curl -s http://192.168.56.150:8888
'
```

## Troubleshooting

### GitLab Not Accessible
```bash
vagrant ssh -- -t 'sudo docker restart gitlab && sleep 30 && sudo docker logs gitlab --tail 50'
```

### ArgoCD Not Syncing
```bash
# Check application status
vagrant ssh -- -t 'kubectl describe application bonus-app -n argocd'

# Force sync
vagrant ssh -- -t 'kubectl delete application bonus-app -n argocd && \
  kubectl apply -f /vagrant/confs/dev/argocd-app.yaml'
```

### Pod Not Updating
```bash
# Check pod status
vagrant ssh -- -t 'kubectl get pods -n dev -o wide'

# Check pod events
vagrant ssh -- -t 'kubectl describe pod -n dev -l app=bonus-app'

# Force pod restart
vagrant ssh -- -t 'kubectl delete pod -n dev -l app=bonus-app'
```

## Notes for Evaluator

- GitLab takes 3-5 minutes to fully start after the VM boots
- ArgoCD auto-sync interval is 3 minutes (can be faster with webhooks)
- The setup uses Docker for GitLab instead of the traditional package installation for reliability
- All Part 3 functionality works identically, but with GitLab instead of GitHub
- The repository is fully local (no external dependencies)
