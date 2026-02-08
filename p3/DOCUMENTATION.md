# Part 3 — ArgoCD + GitHub in K3d

## Overview

Part 3 deploys ArgoCD in a K3d cluster. ArgoCD watches a **public GitHub
repository** containing Kubernetes manifests for the `wil42/playground` app.
When the manifests change (v1 to v2), ArgoCD auto-syncs and updates the
running application.

### What each piece does

| Component | What it is | Role here |
|---|---|---|
| **K3d** | Wrapper that runs a K3s cluster inside Docker containers | Hosts the Kubernetes cluster where ArgoCD and our app live |
| **ArgoCD** | GitOps controller — watches a git repo and keeps a cluster in sync with it | Pulls manifests from GitHub, applies them to the `dev` namespace |
| **wil42/playground** | Tiny HTTP server that returns `{"status":"ok","message":"v1"}` | The application being deployed |

### Architecture

```
iot-eval-vm
│
├── Docker
│   └── K3d cluster "iot"  (Docker containers acting as K8s nodes)
│       ├── argocd namespace  →  ArgoCD pods (watches GitHub)
│       └── dev namespace     →  wil-playground pod (our app)
│
├── localhost:8888  →  wil-playground app  (via K3d port mapping)
└── ArgoCD watches: https://github.com/Franciszer/frthierr-iot-config.git
```

## How it works, step by step

### 1. K3d creates a Kubernetes cluster inside Docker

K3d doesn't use VMs. It creates Docker containers that run K3s (a lightweight
Kubernetes). Our cluster has a single server node — no agents needed.

The flag `-p "8888:30000@server:0"` tells K3d: "anything that arrives on the
VM's port 8888, forward it to port 30000 on the K3s server container". This
is how `curl localhost:8888` reaches our app later.

We disable Traefik (`--disable=traefik`) because we use NodePort, not Ingress.

### 2. ArgoCD is installed into the cluster

ArgoCD is a set of Kubernetes deployments (about 7 pods) installed in the
`argocd` namespace. We apply the official manifest with `kubectl apply`.

Once running, ArgoCD watches git repositories and keeps the cluster in sync.
If someone changes a file in the repo, ArgoCD detects it and re-applies the
manifests automatically (auto-sync with self-heal).

### 3. ArgoCD Application ties it all together

The ArgoCD Application resource (in `confs/argocd/app.yaml`) tells ArgoCD:
- **source**: the GitHub repo at `https://github.com/Franciszer/frthierr-iot-config.git`,
  branch `main`, path `.` (root of the repo)
- **destination**: deploy into the `dev` namespace of this cluster
- **syncPolicy**: automated (auto-sync + prune + self-heal)

ArgoCD clones the repo, finds the two YAML files, and applies them to the
`dev` namespace. The wil-playground Deployment creates a pod, and the
Service exposes it on NodePort 30000.

### 4. Updating v1 to v2

When you change `wil42/playground:v1` to `v2` in the GitHub repo and push,
ArgoCD detects the change (polls every ~3 min by default) and updates the
Deployment. Kubernetes performs a rolling update: it creates a new pod with
the v2 image and terminates the old one. `curl localhost:8888` now returns v2.

## Networking

```
curl localhost:8888
  → VM port 8888  (K3d port mapping)
  → NodePort 30000 on K3d server container
  → wil-playground Service (port 8888)
  → wil-playground Pod (containerPort 8888)
```

Unlike the bonus (where ArgoCD needs to reach a local GitLab container over
Docker networking), P3 uses a public GitHub repo. ArgoCD pods reach GitHub
over the internet — no special networking required.

## File structure

```
p3/
├── run.sh                   # Deploy everything (main entry point)
├── stop.sh                  # Pause cluster (preserves state)
├── clean.sh                 # Destroy cluster completely
├── test.sh                  # Automated checks (6 tests)
├── confs/
│   └── argocd/
│       └── app.yaml         # ArgoCD Application (points to GitHub)
└── DOCUMENTATION.md
```

## Usage

### Deploy everything

```bash
cd ~/Inception-of-Things/p3
./run.sh       # ~3 min (ArgoCD install + sync)
```

### Verify

```bash
./test.sh

# Or manually:
curl http://localhost:8888
kubectl get pods -n dev
kubectl get ns
```

### Access ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Open https://localhost:8080 in a browser
# Username: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

### Update v1 to v2 (the eval demo)

In the GitHub repo (`Franciszer/frthierr-iot-config`):
1. Edit `deployment.yaml`
2. Change `wil42/playground:v1` to `wil42/playground:v2`
3. Commit and push

Wait ~3 min for ArgoCD to auto-sync (or click "Sync" in the UI), then:

```bash
curl http://localhost:8888
# {"status":"ok", "message": "v2"}
```

### Stop / clean

```bash
./stop.sh      # pause (keeps state, can restart)
./clean.sh     # destroy everything
```

## Why these choices

| Decision | Reason |
|---|---|
| Single K3d server, no agents | Saves ~1 GB RAM, sufficient for this workload |
| Traefik disabled | We use NodePort, not Ingress; saves resources |
| `--server-side` for ArgoCD install | The `applicationsets` CRD exceeds the 256 KB annotation limit with client-side apply |
| Public GitHub repo | Subject requires ArgoCD to watch a public repo with `frthierr` in the name |
| Automated sync with selfHeal | ArgoCD auto-detects changes and corrects drift without manual intervention |
