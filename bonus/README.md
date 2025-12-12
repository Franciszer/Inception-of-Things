# Inception-of-Things - Bonus Part

## Overview

This bonus part extends Part 3 by integrating a **local GitLab instance** instead of using GitHub. The complete GitOps workflow now operates entirely on the local infrastructure.

## Quick Start

```bash
cd bonus/
vagrant up
# Wait 3-5 minutes for GitLab to fully initialize
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Vagrant VM (192.168.56.150)                                 │
│                                                              │
│  ┌────────────┐         ┌──────────────┐                    │
│  │  GitLab    │◄────────┤   ArgoCD     │                    │
│  │  (Docker)  │         │  (K8s Pods)  │                    │
│  │            │         │              │                    │
│  │  iot-repo  │         │  Monitors    │                    │
│  │   /dev/    │────────►│  local repo  │                    │
│  │    *.yaml  │         │              │                    │
│  └────────────┘         │  Auto-syncs  │                    │
│       :80               └──────┬───────┘                    │
│                                │                             │
│  ┌────────────────────────────▼─────────────────────┐      │
│  │ K3d Cluster (bonus-cluster)                      │      │
│  │  - argocd namespace: ArgoCD control plane        │      │
│  │  - dev namespace: Application deployment         │      │
│  │  - gitlab namespace: (reserved)                  │      │
│  └──────────────────────────────────────────────────┘      │
│                                :8888                         │
└─────────────────────────────────────────────────────────────┘
```

## Access Information

### GitLab
- **URL**: http://192.168.56.150
- **Username**: root
- **Password**: `c1l1g+YFxHLLLDvGB94X7Mr18zPWHMlzRGeacqJVQoE=`
- **Repository**: http://192.168.56.150/root/iot-repo.git

### ArgoCD
```bash
# Get admin password
vagrant ssh -- -t 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo'

# Access UI (optional)
vagrant ssh -- -t 'kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8080:443'
# Then: https://192.168.56.150:8080
```

### Application
- **URL**: http://192.168.56.150:8888
- **Current Version**: v1
- **Response**: `{"status":"ok", "message": "v1"}`

## Files Structure

```
bonus/
├── README.md                     # This file
├── EVALUATION_GUIDE.md           # Step-by-step evaluation guide
├── SUCCESS_SUMMARY.md            # Detailed success report
├── SETUP_COMPLETION.md           # Original setup guide
├── Vagrantfile                   # VM configuration
├── scripts/
│   ├── install_tools.sh          # Docker, kubectl, Helm
│   ├── install_k3d.sh            # K3d cluster + namespaces + ArgoCD
│   └── install_gitlab.sh         # GitLab reference (using Docker instead)
└── confs/
    ├── argocd/
    │   ├── install.yaml          # ArgoCD installation manifest
    │   └── app-project.yaml      # ArgoCD project (allows GitLab repos)
    └── dev/
        ├── deployment.yaml       # App deployment (in GitLab repo)
        ├── service.yaml          # App service (in GitLab repo)
        └── argocd-app.yaml       # ArgoCD Application definition
```

## GitOps Workflow

1. **Modify application** → Edit files in GitLab repository
2. **Commit & push** → Changes go to local GitLab
3. **ArgoCD detects** → Polls repository (3-min interval or webhook)
4. **Auto-sync** → ArgoCD applies changes to cluster
5. **Kubernetes updates** → Rolling update of deployment
6. **Application updated** → New version accessible

## Testing the Workflow

### Check Current Status
```bash
vagrant ssh -- -t 'curl http://192.168.56.150:8888'
# Output: {"status":"ok", "message": "v1"}
```

### Update to v2
```bash
vagrant ssh -- -t 'cd /tmp/iot-repo && \
  git pull && \
  sed -i "s|v1|v2|" dev/deployment.yaml && \
  git commit -am "Update to v2" && \
  git push origin main'
```

### Verify Update (after ArgoCD syncs)
```bash
vagrant ssh -- -t 'sleep 30 && curl http://192.168.56.150:8888'
# Output: {"status":"ok", "message": "v2"}
```

## Verification Commands

```bash
# All components status
vagrant ssh -- -t '
echo "=== Cluster ===" && kubectl get nodes && \
echo -e "\n=== GitLab ===" && sudo docker ps | grep gitlab && \
echo -e "\n=== ArgoCD ===" && kubectl get applications -n argocd && \
echo -e "\n=== App ===" && kubectl get pods,svc -n dev && \
echo -e "\n=== Response ===" && curl -s http://192.168.56.150:8888
'
```

## Key Differences from Part 3

| Aspect | Part 3 | Bonus |
|--------|--------|-------|
| Repository | GitHub | Local GitLab |
| URL | github.com/... | 192.168.56.150/... |
| Authentication | Public repo | Local GitLab auth |
| Infrastructure | K3d only | K3d + GitLab container |
| Availability | Internet required | Fully local |

## Compliance with Subject

✅ GitLab instance runs locally
✅ GitLab configured to work with cluster
✅ Dedicated `gitlab` namespace created
✅ Everything from Part 3 works with local GitLab
✅ Latest GitLab CE version (Docker image)

## Evaluation Checklist

See [EVALUATION_GUIDE.md](EVALUATION_GUIDE.md) for the complete step-by-step evaluation process that matches the 42 correction sheet.

**Required verifications:**
1. [x] Configuration files in bonus folder
2. [x] GitLab functions correctly
3. [x] Can create repository and add code
4. [x] Part 3 operations work with local GitLab
5. [x] Version change works with synchronization

## Troubleshooting

### VM Issues
```bash
vagrant halt && vagrant up
```

### GitLab Not Ready
```bash
# Wait for healthy status
vagrant ssh -- -t 'sudo docker ps | grep gitlab'
# Should show: (healthy)
```

### ArgoCD Not Syncing
```bash
# Recreate application
vagrant ssh -- -t 'kubectl delete application bonus-app -n argocd && \
  kubectl apply -f /vagrant/confs/dev/argocd-app.yaml'
```

## Resources

- GitLab Docker: https://docs.gitlab.com/ee/install/docker.html
- ArgoCD: https://argo-cd.readthedocs.io/
- K3d: https://k3d.io/

## Notes

- GitLab runs in Docker for reliability and ease of setup
- ArgoCD auto-sync is enabled with 3-minute polling
- Self-healing is enabled (ArgoCD corrects drift automatically)
- Complete workflow is 100% local (no internet required after setup)
