# VM Setup — iot-eval-vm

## Status: READY (tools installed, SSH configured)

## VM Details
- **Name**: `iot-eval-vm`
- **Location**: `/sgoinfre/goinfre/Perso/frthierr/VirtualBox_VMs/iot-eval-vm/`
- **OS**: Ubuntu 22.04.5 Desktop (64-bit)
- **RAM**: 8192 MB | **CPUs**: 4 | **Disk**: 80 GB VDI
- **VRAM**: 128 MB | **Graphics**: VMSVGA + 3D acceleration
- **Nested virtualization**: Enabled
- **Network**: NAT with port forwarding `2222→22` (SSH only)
- **VM user**: `frthierr`
- **SSH from host**: `ssh -p 2222 frthierr@localhost` (passwordless, ed25519 key)
- **Passwordless sudo**: Configured (`/etc/sudoers.d/frthierr`)

## Installed Tools (verified working)
| Tool | Version | Purpose |
|------|---------|---------|
| VirtualBox | 7.0.26 (Oracle repo) | Nested VMs for Parts 1 & 2 |
| Vagrant | 2.2.19 | VM provisioning for Parts 1 & 2 |
| Docker | 27.5.1 | Container runtime for K3d (Part 3) |
| kubectl | v1.35.0 | Kubernetes CLI |
| k3d | v5.8.3 | K3d cluster management (Part 3) |
| helm | v3.20.0 | Package manager (bonus GitLab) |
| ArgoCD CLI | v3.3.0 | ArgoCD management (Part 3) |
| zsh + oh-my-zsh | 5.8.1 | Shell |
| git | 2.34.1 | Version control |
| curl | 7.81.0 | HTTP client |

### Install notes
- VirtualBox installed from Oracle repo (Ubuntu repo's 6.1 fails DKMS on kernel 6.8)
- Required `gcc-12` + `linux-headers` for VBox kernel module build
- Docker: user `frthierr` added to `docker` group (needs re-login or `newgrp docker`)

## Critical Constraints
- **Host `/home/frthierr`** is only 4.7GB — never store large files there
- All large files go in `/sgoinfre/goinfre/Perso/frthierr/`

## Remaining Setup
- [ ] Configure Git SSH keys inside VM for GitHub (needed for Part 3 eval — live push)
- [ ] Build & test all 4 parts (p1, p2, p3, bonus)
- [ ] Export VM to OVA: `VBoxManage export iot-eval-vm -o /sgoinfre/goinfre/Perso/frthierr/iot-eval-vm.ova`

## Project Context

The repo is at `/home/frthierr/Workspace/Inception-of-Things`.

### Folder structure expected at evaluation
```
./p1/Vagrantfile + scripts/ + confs/
./p2/Vagrantfile + scripts/ + confs/
./p3/scripts/ + confs/          <-- must include install script for tools
./bonus/scripts/ + confs/
```

### Parts overview
- **Part 1**: Vagrant + K3s — 2 VMs (frthierrS + frthierrSW), IPs 192.168.56.110/.111, K3s server + agent, 1 CPU / 512-1024 MB RAM each
- **Part 2**: Vagrant + K3s — 1 VM (frthierrS), IP 192.168.56.110, 3 web apps via Ingress (app1.com→app1, app2.com→app2 with 3 replicas, default→app3)
- **Part 3**: K3d + Docker + ArgoCD — 2 namespaces (`argocd` + `dev`), app from public GitHub repo (name must contain login), Docker image with v1/v2 tags, port 8888
- **Bonus**: GitLab in K3d (`gitlab` namespace), latest version, helm. ArgoCD uses local GitLab instead of GitHub.

### Evaluation flow
1. Evaluator clones repo inside this VM
2. Parts 1 & 2: `vagrant up` in p1/ and p2/
3. Part 3: run scripts in p3/scripts/ — evaluator pushes v1→v2 change live on GitHub
4. Bonus: same as Part 3 but with local GitLab
5. Must explain K3s, Vagrant, K3d, ArgoCD, Ingress, namespaces vs pods
