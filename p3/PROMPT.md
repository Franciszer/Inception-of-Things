# Prompt: Build P3 (ArgoCD + GitHub in K3d)

## What is P3

ArgoCD deployed in a K3d cluster, watching a **public GitHub repo** that contains Kubernetes manifests for the `wil42/playground` app. When we push a change to the repo (v1 to v2), ArgoCD auto-syncs and updates the running app.

## Context

- **VM**: `iot-eval-vm` — Ubuntu (22.04 or 24.04), 8GB RAM, 4 CPUs
- **SSH into VM**: `ssh -p 2222 frthierr@localhost` (passwordless, sudo without password)
- **VM user**: `frthierr`
- **Repo inside VM**: `~/Inception-of-Things` on branch `frthierr-dev`
- **P3 runs directly on the VM** — NO Vagrant. K3d creates containers via Docker.

### Tools already installed on iot-eval-vm

Docker 27.5.1, kubectl v1.35.0, k3d v5.8.3, helm v3.20.0, ArgoCD CLI v3.3.0, git, curl. **No installation scripts needed.**

### How files get to the VM

Edit on host, `git push`, then `ssh -p 2222 frthierr@localhost "cd ~/Inception-of-Things && git pull"`.

---

## Subject requirements (pages 12-14)

- K3d cluster on the VM
- **2 namespaces**: `argocd` and `dev`
- ArgoCD installed in `argocd` namespace
- ArgoCD watches a **public GitHub repo** (name must contain `frthierr`)
- App: `wil42/playground` from Dockerhub, port 8888, tags v1 and v2
- `curl http://localhost:8888` returns `{"status":"ok", "message": "v1"}`
- Change v1 to v2 by pushing to GitHub, ArgoCD syncs, app updates

## Correction checklist

### Configuration
1. Config files present in p3/ folder
2. At least 2 namespaces: `argocd` and `dev` (`kubectl get ns`)
3. At least 1 pod in `dev` namespace (`kubectl get pods -n dev`)
4. All required services running
5. ArgoCD installed, accessible via web browser (login/password)
6. GitHub repo name contains `frthierr`
7. Docker image: `wil42/playground`, two tags (v1, v2)
8. Extra files in p3/ must be explainable

### Usage (live during eval)
1. Evaluator navigates ArgoCD UI, we explain how it works
2. v1 app accessible via `curl http://localhost:8888`
3. Dockerhub is used (verify)
4. Update v1 to v2: modify deployment.yaml in GitHub repo, commit+push
5. ArgoCD syncs (auto or manual), app updates to v2
6. Verify synchronization succeeded

---

## Architecture

```
iot-eval-vm (Docker daemon)
└── K3d cluster "iot" (single server node, no agents)
    ├── argocd namespace
    │   └── ArgoCD pods (7 pods: server, repo-server, redis, dex,
    │       app-controller, appset-controller, notifications)
    └── dev namespace
        └── wil-playground pod (deployed by ArgoCD)

ArgoCD watches: https://github.com/Franciszer/frthierr-iot-config.git
Port mapping:   host:8888 → NodePort 30000 → wil-playground:8888
```

No GitLab, no extra Docker containers. Just a K3d cluster with ArgoCD pointing at a public GitHub repo.

---

## GitHub config repo (separate repo, NOT this one)

A **public** GitHub repo named `frthierr-iot-config` under the `Franciszer` GitHub account. Contains two files:

**deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    metadata:
      labels:
        app: wil-playground
    spec:
      containers:
      - name: wil-playground
        image: wil42/playground:v1
        ports:
        - containerPort: 8888
```

**service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: wil-playground
spec:
  type: NodePort
  selector:
    app: wil-playground
  ports:
  - port: 8888
    targetPort: 8888
    nodePort: 30000
```

---

## Files to create in p3/

```
p3/
├── run.sh              # creates cluster, installs ArgoCD, applies app
├── stop.sh             # pause cluster without destroying
├── clean.sh            # full teardown
├── test.sh             # automated eval checks
├── confs/
│   └── argocd/
│       └── app.yaml    # ArgoCD Application (points to GitHub repo)
└── DOCUMENTATION.md
```

### What run.sh should do

1. Sanity checks (not root, docker/k3d/kubectl available)
2. Clean any previous cluster (`clean.sh`)
3. Create K3d cluster:
   - 1 server, 0 agents
   - Port mapping: `8888:30000@server:0` (app access)
   - Disable traefik (we use NodePort, saves resources)
4. Create namespaces: `argocd` and `dev`
5. Install ArgoCD from upstream manifest (`--server-side` required — the applicationsets CRD exceeds 256KB annotation limit)
6. Wait for all ArgoCD deployments to be Available
7. Apply `confs/argocd/app.yaml` (ArgoCD Application pointing to GitHub)
8. Wait for wil-playground deployment in dev namespace
9. Print access info (app URL, ArgoCD credentials, v1→v2 instructions)

### What confs/argocd/app.yaml should be

ArgoCD Application resource:
- repoURL: `https://github.com/Franciszer/frthierr-iot-config.git`
- path: `.`
- targetRevision: `main`
- destination namespace: `dev`
- syncPolicy: automated (prune + selfHeal)

### What test.sh should check

1. K3d cluster is running
2. Namespaces `argocd` and `dev` exist
3. ArgoCD has enough pods running (>=5)
4. At least one wil-playground pod Running in dev
5. App responds on port 8888 with v1 or v2 JSON
6. ArgoCD Application is in Synced state

### Script style

- Comment thoroughly — evaluator will ask what each part does
- Use color variables (`GREEN`, `RED`, `NC`) not raw escape codes
- Keep it simple — no AI-looking boilerplate
- `set -euo pipefail` in all scripts

---

## Existing p3/ files (all broken, from former teammate)

All of these should be deleted:
- `Makefile` — runs scripts with sudo, unnecessary
- `scripts/setup.sh` — installs Docker/kubectl/k3d (already installed)
- `scripts/launch_k3d.sh` — cluster named `ychibani` (wrong login), port 80:80
- `scripts/argocd.sh` — blocks on `kubectl port-forward`
- `scripts/temp.sh` — leftover
- `confs/argocd/ingress.yaml` — misnamed, actually an ArgoCD Application pointing to `ychibani42/iot-app.git`
- `confs/argocd/install.yaml` — 120KB ArgoCD manifest (we fetch fresh instead)

Keep only `.gitignore` and `.gitkeep`.

---

## Reference: bonus/

The `bonus/` directory in this same repo has a working implementation of a similar setup (K3d + ArgoCD + GitLab). Read its scripts for inspiration — especially `bonus/run.sh` which is thoroughly commented. P3 is simpler (no GitLab, no Docker networking tricks, no API tokens), but the K3d cluster creation, ArgoCD install, and wait logic are the same.

---

## Existing p3/ files (all broken, from former teammate — already deleted)

These were removed before starting:
- `Makefile`, `scripts/setup.sh`, `scripts/launch_k3d.sh`, `scripts/argocd.sh`, `scripts/temp.sh`
- `confs/argocd/ingress.yaml`, `confs/argocd/install.yaml`

---

## Task

1. Delete all broken files from p3/ (keep .gitignore, .gitkeep)
2. Create the GitHub repo `frthierr-iot-config` with the two manifests (or tell me the exact steps to do it myself)
3. Write `p3/confs/argocd/app.yaml`
4. Write `p3/run.sh`
5. Write `p3/stop.sh` and `p3/clean.sh`
6. Write `p3/test.sh`
7. Write `p3/DOCUMENTATION.md`
8. Test on the VM
