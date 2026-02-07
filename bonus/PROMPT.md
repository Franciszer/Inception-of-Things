# Prompt: Build Bonus + P3 (ArgoCD & GitLab in K3d)

## Strategy

Build **bonus first** (GitLab + ArgoCD in K3d), then **extract p3** from it (same thing but with GitHub instead of local GitLab). The bonus is a superset of p3.

## Context from previous sessions

We set up a VirtualBox VM called `iot-eval-vm` for the Inception-of-Things project.

- **SSH into VM**: `ssh -p 2222 frthierr@localhost` (passwordless, sudo without password)
- **VM user**: `frthierr`
- **Repo inside VM**: `~/Inception-of-Things` on branch `frthierr-dev`
- **P1**: completed and tested (20/20)
- **P2**: completed and tested — single K3s VM with 3 web apps + HOST-based Ingress
- **P3 and bonus**: existing code from a former teammate, needs complete rewrite (wrong login `ychibani`, broken scripts, mixed Vagrant/direct approaches)

### Tools already installed & verified on iot-eval-vm

- Docker 27.5.1 (user `frthierr` in docker group)
- kubectl v1.35.0
- k3d v5.8.3
- helm v3.20.0
- ArgoCD CLI v3.3.0
- git 2.34.1, curl 7.81.0

**No tool installation scripts are needed.** Everything is pre-installed. The scripts just need to create the K3d cluster and deploy components.

### Critical constraints

- `/home/frthierr` on host machine is only 4.7GB — never store large files there
- All large files go in `/sgoinfre/goinfre/Perso/frthierr/`
- The VM has 8GB RAM, 4 CPUs — resource-conscious choices matter
- P3 and bonus run **directly on iot-eval-vm** — NO Vagrant. K3d creates containers via Docker.

### How files get to the VM

We edit files on the host, `git push`, then `ssh -p 2222 frthierr@localhost "cd ~/Inception-of-Things && git pull"`. There is no synced folder.

---

## Subject Requirements

### Part 3 — K3d and Argo CD (subject pages 12-14)

- Install K3D on the virtual machine (already installed)
- Create **2 namespaces**: `argocd` and `dev`
- `dev` namespace contains an application automatically deployed by ArgoCD from a **public GitHub repository**
- GitHub repo name must contain `frthierr` (e.g., `frthierr-iot` or `frthierr-config`)
- Application: `wil42/playground` from Dockerhub (port 8888), with tags **v1** and **v2**
  - `curl http://localhost:8888` → `{"status":"ok", "message": "v1"}`
- Must be able to change the version by pushing to GitHub, then ArgoCD syncs and the app updates
- The subject shows `kubectl get ns` listing `argocd` + `dev`, and `kubectl get pods -n dev` showing `wil-playground-...`

### Bonus — Local GitLab replaces GitHub (subject page 15 + correction)

- Same as P3 but ArgoCD watches a **local GitLab** repository instead of GitHub
- GitLab must run locally, accessible from the cluster
- A `gitlab` namespace must exist in K3d
- Must be able to: create a GitLab repo, add code, push, and have ArgoCD sync from it
- Version change (v1 → v2) must work via local GitLab just like p3 does via GitHub

---

## Correction Checklist

### Part 3 — Configuration
1. Configuration files present in p3 folder
2. At least 2 namespaces: `argocd` and `dev` (`kubectl get ns`)
3. At least 1 pod in `dev` namespace (`kubectl get pods -n dev`)
4. All required services running
5. ArgoCD installed and configured, accessible via web browser (login/password)
6. GitHub repo name contains `frthierr`
7. Docker image used: `wil42/playground` (or custom with `frthierr` in Dockerhub name), two tags (v1, v2)
8. Extra files in p3 folder must be explainable

### Part 3 — Usage
1. Evaluator navigates ArgoCD UI, group explains how it works
2. v1 application accessible via curl (`curl http://localhost:8888`)
3. Dockerhub is used (verify)
4. Update v1 → v2: modify deployment.yaml in GitHub config repo, commit+push
5. ArgoCD syncs (auto or manual), app updates to v2
6. Verify application was successfully synchronized

### Bonus
1. Configuration files in bonus folder, explainable
2. GitLab functions correctly: create new repo, add code, verify on GitLab
3. Part 3 operations work with **local GitLab repository** (not GitHub)
4. Synchronization + version change (v1 → v2) via local GitLab with no errors

---

## What exists (to rewrite/fix)

### Existing p3/ (from former teammate — all wrong)
- `scripts/setup.sh` — installs Docker, kubectl, k3d (unnecessary, already installed)
- `scripts/launch_k3d.sh` — cluster named `ychibani` (wrong login), port 80:80
- `scripts/argocd.sh` — installs ArgoCD, blocks on `kubectl port-forward`
- `confs/argocd/ingress.yaml` — **misnamed**, it's actually an ArgoCD Application pointing to `github.com/ychibani42/iot-app.git` (wrong repo)
- `confs/argocd/install.yaml` — ArgoCD install manifest (120KB, can reuse or fetch fresh)
- `Makefile` — runs setup+launch+argocd with sudo (fragile)
- **Problems**: wrong login everywhere, port-forward blocks script, no proper app access, redundant installs

### Existing bonus/ (partial work — mixed approaches)
- `run.sh` — creates K3d cluster, installs ArgoCD, installs GitLab via Helm (resource heavy)
- `build.sh` — pre-pulls Docker images (good idea for eval speed)
- `scripts/install_gitlab.sh` — installs GitLab CE via apt (contradicts run.sh Helm approach)
- `scripts/install_k3d.sh` — references `/vagrant/confs/` (Vagrant remnant)
- `confs/argocd/app-project.yaml` — ArgoCD AppProject allowing GitLab repos
- `confs/dev/deployment.yaml` — wil42/playground:v1 deployment
- `confs/dev/service.yaml` — NodePort service on 30000
- `confs/dev/argocd-app.yaml` — ArgoCD Application pointing to `http://192.168.56.150/root/iot-repo.git`
- `validate.sh` — uses `vagrant ssh` (broken, no Vagrant in bonus)
- Multiple MD files auto-generated by AI (SETUP_COMPLETION.md, SUCCESS_SUMMARY.md, EVALUATION_GUIDE.md, README.md)
- `.vagrant/` directory (shouldn't exist, no Vagrantfile)
- **Problems**: mixed Vagrant/direct, GitLab installed two different ways, validate.sh broken, too many generated docs

---

## Implementation Plan

### Phase 1: Bonus (GitLab + ArgoCD in K3d)

**Architecture:**
```
iot-eval-vm
├── Docker daemon
│   ├── K3d cluster ("iot") containers
│   │   ├── argocd namespace → ArgoCD pods
│   │   ├── dev namespace → wil42/playground app
│   │   └── gitlab namespace → (marker namespace)
│   └── GitLab CE container (standalone, outside K3d)
│       └── http://localhost:8181 (or similar port)
```

**Key decision — GitLab approach:** Run GitLab CE as a **standalone Docker container** (not inside K3d via Helm). Reasons:
- Helm GitLab chart needs 6-8GB RAM minimum — won't fit alongside K3d in 8GB VM
- Standalone Docker container is simpler, faster to start, more reliable
- ArgoCD can reach it via Docker network (host.k3d.internal or Docker bridge IP)
- The `gitlab` namespace in K3d is just a marker to satisfy the correction

**Files to create in `bonus/`:**
```
bonus/
├── scripts/
│   └── setup.sh          # Single entry point: creates cluster, installs everything
├── confs/
│   ├── argocd/
│   │   └── app.yaml      # ArgoCD Application (points to local GitLab repo)
│   └── dev/
│       ├── deployment.yaml   # wil42/playground:v1
│       └── service.yaml      # NodePort 30000
├── test.sh               # Automated eval checks
└── DOCUMENTATION.md
```

**setup.sh should:**
1. Start GitLab CE Docker container (port 8181 on host, or pick a free port)
2. Create K3d cluster with port mappings:
   - `8080:80@loadbalancer` (ArgoCD web UI or general)
   - `8888:30000@loadbalancer` (app via NodePort)
3. Create namespaces: `argocd`, `dev`, `gitlab`
4. Install ArgoCD: `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
5. Wait for ArgoCD pods (7 pods running)
6. Wait for GitLab to be healthy
7. Create GitLab repo via API, push `deployment.yaml` + `service.yaml` (v1)
8. Apply ArgoCD Application (watches GitLab repo → deploys to dev namespace)
9. Wait for app to be running in dev namespace
10. Print access info (ArgoCD password, GitLab password, app URL)

**For ArgoCD to reach GitLab (outside K3d):**
- GitLab runs on the Docker host
- From inside K3d pods, the host is reachable via the Docker bridge gateway IP
- K3d provides `host.k3d.internal` DNS or you can use the gateway IP
- ArgoCD Application `repoURL` should use this address

**ArgoCD UI access:**
- Either port-forward in background: `kubectl port-forward svc/argocd-server -n argocd 8080:443 &`
- Or expose via K3d port mapping + Ingress/NodePort

### Phase 2: P3 (extract from bonus, use GitHub)

**Differences from bonus:**
- No GitLab — ArgoCD watches a **public GitHub repo** instead
- No `gitlab` namespace needed (but doesn't hurt)
- Need a GitHub repo named e.g. `frthierr-iot-config` containing `deployment.yaml` + `service.yaml`
- ArgoCD Application `repoURL` points to `https://github.com/Franciszer/frthierr-iot-config.git` (or similar)
- During eval: change v1→v2 in the GitHub repo, push, ArgoCD syncs

**Files in `p3/`:**
```
p3/
├── scripts/
│   └── setup.sh          # Creates cluster, installs ArgoCD, applies app
├── confs/
│   └── argocd-app.yaml   # ArgoCD Application (points to GitHub repo)
├── test.sh
└── DOCUMENTATION.md
```

**GitHub config repo** (separate repo, e.g. `frthierr-iot-config`):
```
deployment.yaml     # wil42/playground:v1
service.yaml        # NodePort 30000
```

---

## Cleanup before starting

Delete all auto-generated/broken files from bonus:
- `bonus/.vagrant/` (no Vagrant here)
- `bonus/.claude/` (leftover settings)
- `bonus/SETUP_COMPLETION.md`, `bonus/SUCCESS_SUMMARY.md`, `bonus/EVALUATION_GUIDE.md` (auto-generated)
- `bonus/README.md` (will rewrite)
- `bonus/validate.sh` (uses vagrant ssh, broken)
- `bonus/scripts/install_tools.sh` (tools already installed)
- `bonus/scripts/install_gitlab.sh` (wrong approach — apt install)
- `bonus/scripts/install_k3d.sh` (references /vagrant/)
- `bonus/scripts/cleanup.sh` (will be in setup.sh)
- `bonus/build.sh`, `bonus/run.sh`, `bonus/stop.sh` (will consolidate into setup.sh)

Delete broken p3 files:
- `p3/Makefile` (unnecessary)
- `p3/scripts/temp.sh` (leftover)
- `p3/scripts/setup.sh` (installs already-installed tools)
- `p3/scripts/launch_k3d.sh` (wrong login)
- `p3/scripts/argocd.sh` (blocks on port-forward)
- `p3/confs/argocd/ingress.yaml` (misnamed, wrong repo)
- `p3/confs/argocd/install.yaml` (120KB, fetch fresh instead)

Keep from bonus:
- `confs/dev/deployment.yaml` and `service.yaml` (good, just verify)
- `confs/argocd/install.yaml` (120KB ArgoCD manifest — can reuse or fetch fresh)

---

## Lessons from p1/p2

- K3s/K3d handle kernel requirements internally — no sysctls, modprobe, swap needed
- Disable apt-daily timers to avoid dpkg lock: `systemctl disable --now apt-daily*`
- Test scripts should use `grep -F` for name checks to support Ruby interpolation
- Keep scripts idempotent (check before creating/installing)
- Deploy to `default` namespace when correction expects `kubectl get all` without `-n`
  - But for p3, the subject explicitly shows `kubectl get pods -n dev`, so **use the `dev` namespace**
- Don't over-engineer: single `setup.sh` entry point, no Makefiles
- Push+pull workflow: edit on host, push, pull inside VM
