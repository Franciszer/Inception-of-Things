# IoT Bonus Part - Setup Completion Guide

## Current Status

The bonus environment is partially set up:
- ✅ K3d cluster running with ArgoCD
- ✅ Namespaces created (argocd, dev, gitlab)
- ⏳ GitLab Docker container being deployed

## Remaining Setup Steps

### 1. Wait for GitLab to Start

GitLab takes 3-5 minutes to fully initialize after the container starts.

```bash
# Check if GitLab container is running
vagrant ssh -- -t 'sudo docker ps | grep gitlab'

# Check GitLab logs to see initialization progress
vagrant ssh -- -t 'sudo docker logs gitlab 2>&1 | tail -20'

# Wait for "gitlab Reconfigured!" message
```

### 2. Get GitLab Root Password

```bash
# Get the initial root password
vagrant ssh -- -t 'sudo docker exec -it gitlab grep "Password:" /etc/gitlab/initial_root_password'
```

### 3. Access GitLab Web UI

Open browser to: http://192.168.56.150
- Username: `root`
- Password: (from step 2)

### 4. Create GitLab Repository

Via Web UI:
1. Click "New project" → "Create blank project"
2. Project name: `iot-repo`
3. Visibility: Public
4. Initialize with README: ✓
5. Create project

### 5. Push Kubernetes Manifests to GitLab

```bash
# On your host machine, create a temporary git repo
cd /tmp
mkdir iot-repo && cd iot-repo
git init
git config user.name "IoT Bonus"
git config user.email "iot@example.com"

# Create dev directory with manifests
mkdir dev
cat > dev/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bonus-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bonus-app
  template:
    metadata:
      labels:
        app: bonus-app
    spec:
      containers:
      - name: bonus-app
        image: wil42/playground:v1
        ports:
        - containerPort: 8888
EOF

cat > dev/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: bonus-app
spec:
  type: NodePort
  selector:
    app: bonus-app
  ports:
  - port: 8888
    targetPort: 8888
    nodePort: 30000
EOF

# Commit and push
git add .
git commit -m "Initial commit: Add Kubernetes manifests"
git remote add origin http://192.168.56.150/root/iot-repo.git
git push -u origin main
# Enter root username and password when prompted
```

### 6. Verify ArgoCD Syncs from GitLab

```bash
# Check ArgoCD application status
vagrant ssh -- -t 'kubectl get applications -n argocd'

# Get ArgoCD admin password
vagrant ssh -- -t 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo'

# Port forward ArgoCD UI (optional, from your host)
vagrant ssh -- -t 'kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8080:443'
# Then access: https://192.168.56.150:8080
# Username: admin
# Password: (from command above)
```

### 7. Verify the Application is Running

```bash
# Check if pods are running in dev namespace
vagrant ssh -- -t 'kubectl get pods -n dev'

# Check the service
vagrant ssh -- -t 'kubectl get svc -n dev'

# Test the application
curl http://192.168.56.150:8888
```

## Troubleshooting

### GitLab Not Starting
```bash
# Check container status
vagrant ssh -- -t 'sudo docker ps -a | grep gitlab'

# View full logs
vagrant ssh -- -t 'sudo docker logs gitlab'

# Restart if needed
vagrant ssh -- -t 'sudo docker restart gitlab'
```

### ArgoCD Not Syncing
```bash
# Check application status
vagrant ssh -- -t 'kubectl describe application bonus-app -n argocd'

# Check ArgoCD logs
vagrant ssh -- -t 'kubectl logs -n argocd deployment/argocd-server'
```

### Repository Authentication Issues

If ArgoCD can't access the GitLab repo:
1. Make sure the repository is set to "Public" in GitLab
2. Or configure ArgoCD with GitLab credentials:

```bash
vagrant ssh -- -t 'kubectl -n argocd create secret generic gitlab-secret \
  --from-literal=username=root \
  --from-literal=password=YOUR_PASSWORD'
```

Then update the Application to reference the secret.

## Project Structure

```
bonus/
├── Vagrantfile              # VM configuration
├── scripts/
│   ├── install_tools.sh     # Docker, kubectl, Helm
│   ├── install_k3d.sh       # K3d cluster + namespaces
│   └── install_gitlab.sh    # GitLab (reference, using Docker instead)
├── confs/
│   ├── argocd/
│   │   ├── install.yaml     # ArgoCD installation manifest
│   │   └── app-project.yaml # ArgoCD project
│   └── dev/
│       ├── deployment.yaml  # Sample app deployment
│       ├── service.yaml     # Sample app service
│       └── argocd-app.yaml  # ArgoCD application pointing to GitLab
└── SETUP_COMPLETION.md      # This file
```

## Expected Final State

- GitLab running at http://192.168.56.150
- ArgoCD managing the `bonus-app` Application
- Application deployed to `dev` namespace
- Application accessible on port 8888 (mapped to NodePort 30000)
- Complete GitOps workflow: Push to GitLab → ArgoCD syncs → App updates
