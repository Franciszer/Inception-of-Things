# Bonus — GitLab + ArgoCD in K3d

## Overview

The bonus replaces the GitHub repository from Part 3 with a **local GitLab
instance deployed inside the K3d cluster**. ArgoCD watches a GitLab repo
instead of a GitHub one, so the entire GitOps pipeline runs locally with no
internet dependency.

### What each piece does

| Component | What it is | Role here |
|---|---|---|
| **K3d** | Wrapper that runs a K3s cluster inside Docker containers | Hosts the Kubernetes cluster where everything lives |
| **ArgoCD** | GitOps controller — watches a git repo and keeps a cluster in sync with it | Pulls manifests from GitLab, applies them to the `dev` namespace |
| **GitLab CE** | Self-hosted git forge (like GitHub), deployed as a K8s Deployment | Hosts the `iot-config` repo that ArgoCD watches |
| **wil42/playground** | Tiny HTTP server that returns `{"status":"ok","message":"v1"}` | The application being deployed |

### Architecture

```
iot-eval-vm
│
└── Docker
    └── K3d cluster "bonus"  (Docker containers acting as K8s nodes)
        ├── argocd namespace  →  ArgoCD pods (watches GitLab via K8s DNS)
        ├── gitlab namespace  →  GitLab CE pod (git server)
        └── dev namespace     →  wil-playground pod (deployed by ArgoCD)

Port mappings (host → K3d NodePort):
  localhost:8888  →  NodePort 30000  →  wil-playground app
  localhost:8080  →  NodePort 30080  →  ArgoCD web UI
  localhost:8181  →  NodePort 30181  →  GitLab web UI
```

## How it works, step by step

### 1. K3d creates a Kubernetes cluster inside Docker

K3d doesn't use VMs. It creates Docker containers that run K3s (a lightweight
Kubernetes). Our cluster has a single server node — no agents needed.

The `-p` flags tell K3d to forward host ports to NodePorts inside the cluster:
- `8888:30000` — the wil-playground app
- `8080:30080` — ArgoCD UI
- `8181:30181` — GitLab UI

We disable Traefik (`--disable=traefik`) because we use NodePort, not Ingress.

### 2. ArgoCD is installed into the cluster

ArgoCD is a set of Kubernetes deployments (about 7 pods) installed in the
`argocd` namespace. We apply the official manifest with `kubectl apply`.

Once running, ArgoCD watches git repositories and keeps the cluster in sync.
If someone changes a file in the repo, ArgoCD detects it and re-applies the
manifests automatically (auto-sync with self-heal).

Reconciliation is tuned to 10 seconds (from the 3-minute default) so the
v1→v2 demo during eval is quick.

### 3. GitLab runs as a Kubernetes Deployment

GitLab CE is deployed as a single-replica Deployment in the `gitlab` namespace,
using the `gitlab/gitlab-ce:latest` Omnibus image. Key configuration:

- **external_url** set to `http://gitlab-ce.gitlab.svc.cluster.local` (K8s DNS)
- **monitoring_whitelist** allows all IPs so kubelet health probes work
- **Startup probe** gives GitLab up to 10 minutes to boot (60 × 10s)
- **Memory limit** of 5Gi to prevent OOMKill
- **/dev/shm** mounted as emptyDir (required by bundled PostgreSQL)

The Service exposes GitLab on NodePort 30181, mapped to host port 8181.

### 4. A git repo is seeded with manifests

The setup script creates a personal access token via `gitlab-rails runner`,
then uses the GitLab API to create a public repo `root/iot-config` and pushes
two files: `deployment.yaml` (wil42/playground:v1) and `service.yaml`
(NodePort 30000).

### 5. ArgoCD Application ties it all together

The ArgoCD Application resource (in `confs/argocd/app.yaml`) tells ArgoCD:
- **source**: `http://gitlab-ce.gitlab.svc.cluster.local/root/iot-config.git`
  (Kubernetes DNS — no IP substitution needed)
- **destination**: deploy into the `dev` namespace of this cluster
- **syncPolicy**: automated (auto-sync + prune + self-heal)

### 6. Updating v1 to v2

When you change `wil42/playground:v1` to `v2` in the GitLab repo and push,
ArgoCD detects the change (polls every 10 seconds) and updates the Deployment.
Kubernetes performs a rolling update: it creates a new pod with the v2 image
and terminates the old one. `curl localhost:8888` now returns v2.

## Networking

```
ArgoCD pod  →  K8s DNS  →  GitLab Service  →  GitLab pod
                            (gitlab-ce.gitlab.svc.cluster.local)
```

Since GitLab runs inside the cluster, ArgoCD reaches it via standard
Kubernetes DNS. No Docker network tricks or IP discovery needed.

For the host (evaluator's browser):
```
curl localhost:8888
  → VM port 8888  (K3d port mapping)
  → NodePort 30000 on K3d server container
  → wil-playground Service (port 8888)
  → wil-playground Pod (containerPort 8888)
```

## File structure

```
bonus/
├── scripts/
│   ├── build.sh             # Pre-pull images (run once, saves time)
│   ├── run.sh               # Deploy everything (main entry point)
│   ├── stop.sh              # Pause cluster (preserves state)
│   ├── clean.sh             # Destroy cluster completely
│   └── test.sh              # Automated checks (11 tests incl. selfHeal)
├── confs/
│   ├── argocd/
│   │   └── app.yaml         # ArgoCD Application (uses K8s DNS for GitLab)
│   ├── dev/
│   │   ├── deployment.yaml  # wil42/playground:v1 — pushed to GitLab
│   │   └── service.yaml     # NodePort 30000 — pushed to GitLab
│   └── gitlab/
│       ├── deployment.yaml  # GitLab CE Deployment (Omnibus image)
│       └── service.yaml     # GitLab NodePort 30181
├── DOCUMENTATION.md
└── PROMPT.md
```

## Usage

### First time (or before eval)

```bash
cd ~/Inception-of-Things
bonus/scripts/build.sh     # pre-pull images so run.sh is faster
```

### Deploy everything

```bash
bonus/scripts/run.sh       # ~15 min (image import + GitLab boot)
```

### Verify

```bash
bonus/scripts/test.sh

# Or manually:
curl http://localhost:8888
kubectl get pods -n dev
kubectl get pods -n gitlab
kubectl get ns
```

### Access ArgoCD UI

Open http://localhost:8080 in a browser.

- **Username**: `frthierr`
- **Password**: `password42`

No `kubectl port-forward` needed — ArgoCD is exposed via NodePort.

### Update v1 to v2 (the eval demo)

```bash
git clone http://root:password42@localhost:8181/root/iot-config.git /tmp/iot-config
cd /tmp/iot-config
sed -i 's/playground:v1/playground:v2/' deployment.yaml
git commit -am 'v2'
git push http://root:password42@localhost:8181/root/iot-config.git main
```

Wait ~10s for ArgoCD to sync, then:

```bash
curl http://localhost:8888
# {"status":"ok", "message": "v2"}
```

### Stop / clean

```bash
bonus/scripts/stop.sh      # pause (keeps state, can restart)
bonus/scripts/clean.sh     # destroy everything
```

## Why these choices

| Decision | Reason |
|---|---|
| GitLab as K8s Deployment | Subject requires GitLab in the `gitlab` namespace as part of the cluster |
| 5Gi memory limit | GitLab CE needs 3-4GB; 3Gi caused OOMKill |
| 12GB VM RAM | 8GB was too tight for GitLab + ArgoCD + K3d together |
| Single K3d server, no agents | Saves ~1 GB RAM, sufficient for this workload |
| Traefik disabled | We use NodePort, not Ingress; saves resources |
| `--server-side` for ArgoCD install | The `applicationsets` CRD exceeds the 256 KB annotation limit with client-side apply |
| Heredoc for Rails runner | `create!` exclamation mark gets escaped through kubectl exec + zsh; heredoc stdin avoids all shell interpretation |
| K8s DNS for ArgoCD→GitLab | `gitlab-ce.gitlab.svc.cluster.local` — no IP discovery or sed substitution needed |
| Pre-pulled images via `build.sh` | GitLab CE is ~3GB; pre-pulling avoids download during eval |
