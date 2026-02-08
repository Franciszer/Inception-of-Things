# Bonus — GitLab + ArgoCD in K3d

## Overview

The bonus replaces the GitHub repository from Part 3 with a **local GitLab
instance**. ArgoCD watches a GitLab repo instead of a GitHub one, so the
entire GitOps pipeline runs locally with no internet dependency.

### What each piece does

| Component | What it is | Role here |
|---|---|---|
| **K3d** | Wrapper that runs a K3s cluster inside Docker containers | Hosts the Kubernetes cluster where ArgoCD and our app live |
| **ArgoCD** | GitOps controller — watches a git repo and keeps a cluster in sync with it | Pulls manifests from GitLab, applies them to the `dev` namespace |
| **GitLab CE** | Self-hosted git forge (like GitHub) | Hosts the `iot-config` repo that ArgoCD watches |
| **wil42/playground** | Tiny HTTP server that returns `{"status":"ok","message":"v1"}` | The application being deployed |

### Architecture

```
iot-eval-vm
│
├── Docker
│   ├── K3d cluster "iot"  (Docker containers acting as K8s nodes)
│   │   ├── argocd namespace  →  ArgoCD pods (watches GitLab)
│   │   ├── dev namespace     →  wil-playground pod (our app)
│   │   └── gitlab namespace  →  empty (marker for correction)
│   │
│   └── gitlab-ce container   (standalone, same Docker network)
│       └── repo: root/iot-config  (deployment.yaml + service.yaml)
│
├── localhost:8888  →  wil-playground app  (via K3d port mapping)
└── localhost:8181  →  GitLab web UI       (via Docker port mapping)
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

### 3. GitLab runs as a Docker container

We don't install GitLab inside the K3d cluster (the Helm chart needs 6+ GB
RAM). Instead, we run it as a standalone Docker container on the same Docker
network as the K3d nodes (`k3d-iot`).

This means:
- From the VM host: GitLab is at `localhost:8181` (Docker port mapping)
- From ArgoCD pods: GitLab is at `172.18.0.x:80` (Docker network IP)

The `gitlab` namespace inside K3d exists purely to satisfy the correction
checklist — it has no pods.

### 4. A git repo is seeded with manifests

The setup script creates a public repo `root/iot-config` on GitLab and pushes
two files: `deployment.yaml` (the wil42/playground:v1 Deployment) and
`service.yaml` (a NodePort Service on port 30000).

### 5. ArgoCD Application ties it all together

The ArgoCD Application resource (in `confs/argocd/app.yaml`) tells ArgoCD:
- **source**: the GitLab repo at `http://<gitlab-ip>/root/iot-config.git`,
  branch `main`, path `.` (root of the repo)
- **destination**: deploy into the `dev` namespace of this cluster
- **syncPolicy**: automated (auto-sync + prune + self-heal)

ArgoCD clones the repo, finds the two YAML files, and applies them to the
`dev` namespace. The wil-playground Deployment creates a pod, and the
Service exposes it on NodePort 30000.

### 6. Updating v1 to v2

When you change `wil42/playground:v1` to `v2` in the GitLab repo and push,
ArgoCD detects the change (polls every ~3 min by default) and updates the
Deployment. Kubernetes performs a rolling update: it creates a new pod with
the v2 image and terminates the old one. `curl localhost:8888` now returns v2.

## Networking explained

The trickiest part is how ArgoCD (inside K3d pods) reaches GitLab (a standalone
Docker container).

```
ArgoCD pod  →  K3s internal network  →  K3d node container  →  Docker network  →  GitLab container
 (10.42.x.x)                           (172.18.0.2)           (k3d-iot)          (172.18.0.4)
```

K3d node containers are regular Docker containers. They're on the `k3d-iot`
Docker network. The GitLab container is also on `k3d-iot` (via `--network
k3d-iot`). So from any K3d node, GitLab is reachable at its Docker IP.

Pods inside K3d route external traffic through the node, so they can also
reach GitLab's Docker IP. That's why the ArgoCD Application uses
`http://172.18.0.x/root/iot-config.git` as the repoURL.

This IP is discovered at setup time and injected into the Application YAML
via `sed`.

## File structure

```
bonus/
├── scripts/
│   └── setup.sh            # Single entry point — run this
├── confs/
│   ├── argocd/
│   │   └── app.yaml         # ArgoCD Application (GITLAB_HOST placeholder)
│   └── dev/
│       ├── deployment.yaml  # wil42/playground:v1 — pushed to GitLab
│       └── service.yaml     # NodePort 30000 — pushed to GitLab
├── test.sh                  # Automated checks (10 tests)
├── DOCUMENTATION.md
└── PROMPT.md                # Design notes
```

## Usage

### Deploy everything

```bash
cd ~/Inception-of-Things
bash bonus/scripts/setup.sh
```

Takes ~5 minutes (most of it is GitLab starting up).

### Verify

```bash
bash bonus/test.sh

# Or manually:
curl http://localhost:8888                         # app response
kubectl get pods -n dev                            # app pod
kubectl get pods -n argocd                         # argocd pods
kubectl get ns                                     # argocd, dev, gitlab
kubectl get application wil-playground -n argocd   # Synced + Healthy
docker ps | grep gitlab-ce                         # GitLab container
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

```bash
git clone http://root:password42@localhost:8181/root/iot-config.git /tmp/iot-config
cd /tmp/iot-config
sed -i 's/playground:v1/playground:v2/' deployment.yaml
git commit -am 'v2'
git push http://root:password42@localhost:8181/root/iot-config.git main
```

Wait ~30s for ArgoCD to sync, then:

```bash
curl http://localhost:8888
# {"status":"ok", "message": "v2"}
```

### Tear down

```bash
k3d cluster delete iot
docker rm -f gitlab-ce
```

## Why these choices

| Decision | Reason |
|---|---|
| GitLab as Docker container, not Helm chart | Helm GitLab needs 6-8 GB RAM — won't fit in 8 GB VM alongside K3d + ArgoCD |
| Single K3d server, no agents | Saves ~1 GB RAM, sufficient for this workload |
| Traefik disabled | We use NodePort, not Ingress; saves resources |
| `--server-side` for ArgoCD install | The `applicationsets` CRD exceeds the 256 KB annotation limit with client-side apply |
| Personal access token via Rails console | GitLab API rejects HTTP basic auth; `gitlab-rails runner` is the only way to create a token non-interactively |
| Password auth for git push | The token created during setup can't be retrieved later (encrypted at rest), so the evaluator uses `root:password42` for the v1→v2 demo |
