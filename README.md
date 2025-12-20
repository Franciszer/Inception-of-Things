# Inception-of-Things (IoT)

A comprehensive Kubernetes infrastructure project using K3s/K3d, ArgoCD, and GitOps workflows with a golden image approach.

## 📚 Project Overview

This project demonstrates progressive Kubernetes concepts through 4 parts, all deployable from a single pre-built VM:

1. **Part 1 (P1)**: Multi-node K3s cluster with Vagrant (2 VMs)
2. **Part 2 (P2)**: K3s server with 3 applications and Ingress (1 VM)
3. **Part 3 (P3)**: K3d cluster with ArgoCD and continuous deployment
4. **Bonus**: K3d with ArgoCD + GitLab integration

## 🎯 Golden Image Approach

This project uses a **golden image** strategy built with Packer:
- **One VM with everything pre-cached**: Docker images, Helm charts, tools
- **Fast deployment**: No downloads during evaluation (offline-capable)
- **Build once, run many times**: 60-90 min build → instant deployments

## 📁 Project Structure

```
Inception-of-Things/
├── README.md                    # This file
├── build.sh                     # Build the golden VM image
├── run.sh                       # Import and start the VM
├── destroy.sh                   # Clean up VM and resources
│
├── packer-vm/                   # Packer configuration
│   ├── iot.pkr.hcl             # Main Packer template (Ubuntu 24.04)
│   ├── build.sh                 # Packer build script
│   ├── run.sh                   # VM import and start
│   ├── http/
│   │   ├── user-data           # Ubuntu autoinstall config
│   │   └── meta-data
│   └── scripts/                 # Provisioning scripts
│       ├── 01-base.sh          # Base system setup
│       ├── 02-docker.sh        # Docker installation
│       ├── 03-k8s-tools.sh     # kubectl, k3d, helm
│       ├── 04-vagrant.sh       # Vagrant + VirtualBox
│       ├── 05-project-setup.sh # Clone repo and pre-cache
│       └── 99-cleanup.sh       # Final cleanup
│
├── p1/                          # Part 1: K3s + Vagrant (2 VMs)
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
│
├── p2/                          # Part 2: K3s + 3 Apps (1 VM)
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
│
├── p3/                          # Part 3: K3d + ArgoCD
│   ├── build.sh                 # Pre-cache dependencies
│   ├── run.sh                   # Deploy K3d + ArgoCD
│   ├── stop.sh                  # Clean up
│   ├── scripts/
│   └── confs/
│
└── bonus/                       # Bonus: GitLab + ArgoCD
    ├── build.sh                 # Pre-cache Docker images & Helm charts
    ├── run.sh                   # Deploy K3d + ArgoCD + GitLab
    ├── stop.sh                  # Clean up
    ├── scripts/
    └── confs/
        ├── argocd/              # ArgoCD manifests
        ├── dev/                 # Application manifests
        └── gitlab/              # GitLab configuration
```

## 🚀 Quick Start

### Build the Golden Image (One-time, 60-90 min)

```bash
# Build the VM with all dependencies pre-cached
./build.sh

# Output:
# - VM image: ~/.../iot-storage/output-iot-eval/iot-eval-vm.ova
# - Log: /tmp/iot-build-YYYYMMDD-HHMMSS.log
# - Build time will be displayed at the end
```

The build script:
- ✅ Auto-installs Packer if not present
- ✅ Runs in background (non-blocking)
- ✅ Logs everything with timestamps
- ✅ Shows total build duration
- ✅ Pre-caches all Docker images and Helm charts

**Monitor progress:**
```bash
tail -f /tmp/iot-build-*.log
```

### Run the VM (< 2 minutes)

```bash
# Import and start the pre-built VM
./run.sh

# The VM will:
# - Import from .ova file
# - Start in headless mode
# - Wait for SSH to be ready
# - Display connection info
```

### Clean Up

```bash
# Stop and remove the VM
./destroy.sh
```

## 📋 System Requirements

### Host Machine (for building)
- **CPU**: 4+ cores with VT-x/AMD-V enabled
- **RAM**: 8 GB minimum (16 GB recommended)
- **Disk**: 30 GB free space
- **OS**: Linux with VirtualBox installed

### VM Specifications (auto-configured by Packer)
- **CPUs**: 4 cores
- **RAM**: 4096 MB
- **Disk**: 100 GB (dynamically allocated)
- **Network**: NAT + Host-only adapter
- **Nested Virtualization**: Enabled

## 🔧 Configuration

### Environment Variables

**`IOT_OUTPUT_DIR`** - Change where the VM is built
```bash
# Default: /home/frthierr/sgoinfre/frthierr/iot-storage
export IOT_OUTPUT_DIR=/custom/path
./build.sh
```

**`DOCKER_USERNAME` / `DOCKER_PASSWORD`** - Avoid Docker Hub rate limits
```bash
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-password"
./build.sh
```

**`IOT_SSH_KEY`** - Custom SSH key path
```bash
# Default: ~/.ssh/iot-vm-key
export IOT_SSH_KEY=/path/to/key
./run.sh
```

## 📦 What's Pre-cached in the VM

### Docker Images (Bonus Part)
- `rancher/k3s:v1.34.2-k3s1` - K3s distribution
- `ghcr.io/k3d-io/k3d-tools:5.8.3` - K3d tools
- `ghcr.io/k3d-io/k3d-proxy:5.8.3` - K3d proxy
- `quay.io/argoproj/argocd:v3.2.0` - ArgoCD
- `wil42/playground:v1` - Application v1
- `wil42/playground:v2` - Application v2
- `nginx:1.27-alpine` - Nginx

### Helm Charts
- GitLab CE (cached locally at `~/.cache/helm-charts/`)

### Tools Installed
- Docker Engine (latest)
- kubectl (latest stable)
- k3d (latest)
- Helm (latest)
- Vagrant (latest)
- VirtualBox (from repository)
- Git, curl, wget, etc.

## 🎮 Running the Parts

Once the VM is running, SSH into it:

```bash
ssh -i ~/.ssh/iot-vm-key -p 2222 ychibani@localhost
```

### Part 1: K3s Multi-node Cluster

```bash
cd ~/Inception-of-Things/p1
./run.sh

# Verify
kubectl get nodes
# Should show 2 nodes: frthierrS (server) and frthierrSW (agent)

./stop.sh
```

### Part 2: K3s with Applications

```bash
cd ~/Inception-of-Things/p2
./run.sh

# Test applications
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110  # Default → app3

./stop.sh
```

### Part 3: K3d + ArgoCD

```bash
cd ~/Inception-of-Things/p3
./run.sh

# Access ArgoCD
# UI: http://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Test application
curl http://localhost:8888

./stop.sh
```

### Bonus: GitLab + ArgoCD

```bash
cd ~/Inception-of-Things/bonus
./run.sh

# Access services
# ArgoCD UI: http://localhost:8080
# GitLab UI: http://localhost:8081
# Application: http://localhost:8888

# Check status
kubectl get pods -n argocd
kubectl get pods -n gitlab
kubectl get pods -n dev

./stop.sh
```

## ⏱️ Time Breakdown

| Task | Time | Notes |
|------|------|-------|
| Initial build | 60-90 min | One-time, includes all downloads |
| Import VM | < 2 min | From .ova file |
| P1 deployment | ~3 min | Vagrant up 2 VMs |
| P2 deployment | ~2 min | Vagrant up 1 VM |
| P3 deployment | ~1 min | K3d on host (pre-cached) |
| Bonus deployment | ~5 min | K3d + GitLab (pre-cached Helm chart) |

**Total evaluation time**: ~15 minutes (after initial build)

## 🔑 Key Features

### Docker Rate Limit Handling
- ✅ Retry logic with exponential backoff (30s, 60s, 120s, 240s)
- ✅ 5s delay between different image pulls
- ✅ Optional Docker Hub authentication support
- ✅ Informative error messages

### Build Features
- ✅ Non-blocking background execution
- ✅ Timestamped logs (`[YYYY-MM-DD HH:MM:SS]`)
- ✅ Total build duration displayed
- ✅ Configurable output directory
- ✅ Automatic Packer installation
- ✅ Progress monitoring with `tail -f`

### Deployment Features
- ✅ Idempotent scripts (safe to run multiple times)
- ✅ Pre-cached dependencies (offline-capable)
- ✅ Automatic resource cleanup
- ✅ Clear separation: build vs run vs stop
- ✅ No manual configuration needed

## 🛠️ Troubleshooting

### Build fails with "rate limit" error
```bash
# Option 1: Set Docker Hub credentials
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-password"
./build.sh

# Option 2: Wait and retry (rate limits reset after 6 hours)
```

### SSH connection fails
```bash
# Clean up known_hosts
ssh-keygen -f ~/.ssh/known_hosts -R "[localhost]:2222"

# Or use destroy script which does this automatically
./destroy.sh
```

### Not enough disk space
```bash
# Change output directory to larger partition
export IOT_OUTPUT_DIR=/path/to/larger/disk
./build.sh

# After build completes, you can delete the .vdi file to save 14 GB
rm ${IOT_OUTPUT_DIR}/output-iot-eval/iot-eval-vm.vdi
```

### Build takes too long
This is normal! The build:
1. Downloads Ubuntu 24.04 ISO (~2 GB)
2. Installs Ubuntu from scratch
3. Installs all packages and tools
4. Pre-caches all Docker images (~3-4 GB)
5. Downloads GitLab Helm chart (~100 MB)
6. Exports to compressed .ova (~8-10 GB)

Expected time: **60-90 minutes**

## 📊 Build Output

```
================================
Inception-of-Things VM Builder
================================
Build PID: 123456
Output dir: /home/frthierr/sgoinfre/frthierr/iot-storage
Log file: /tmp/iot-build-20251220-162341.log

Monitor progress:
  tail -f /tmp/iot-build-20251220-162341.log

To use a different output directory:
  export IOT_OUTPUT_DIR=/your/path

This will take 60-90 minutes...
================================
```

## 📝 Log Format

All logs include timestamps for easy tracking:

```
[2025-12-20 16:23:15] ================================
[2025-12-20 16:23:15] Build started
[2025-12-20 16:23:15] ================================
...
[2025-12-20 17:45:32] ================================
[2025-12-20 17:45:32] VM build complete!
[2025-12-20 17:45:32] ================================
[2025-12-20 17:45:32] Build duration: 82m 17s
```

## 🎯 Project Goals Achieved

✅ **Part 1**: Multi-node K3s cluster with Vagrant
✅ **Part 2**: K3s with multiple applications and Ingress
✅ **Part 3**: K3d cluster with ArgoCD continuous deployment
✅ **Bonus**: Complete GitOps pipeline with local GitLab
✅ **Golden Image**: Everything pre-cached for fast deployment
✅ **Automation**: One-command build, run, and destroy
✅ **Documentation**: Comprehensive guides and inline comments

## 📖 Additional Documentation

- **VM Architecture**: Nested virtualization explained
- **Packer Template**: See `packer-vm/iot.pkr.hcl`
- **Provisioning Scripts**: See `packer-vm/scripts/`
- **ArgoCD Configuration**: See `bonus/confs/argocd/`
- **GitLab Setup**: See `bonus/confs/gitlab/`

## 🤝 Contributing

This is a school project (42 School - Inception-of-Things).
Improvements and suggestions welcome!

## 📜 License

Educational project - MIT License

## 🎓 Credits

- **42 School** - Project specification
- **HashiCorp Packer** - VM automation
- **K3s/K3d** - Lightweight Kubernetes
- **ArgoCD** - GitOps continuous delivery
- **GitLab CE** - Source control and CI/CD

---

**Ready for evaluation! 🚀**

Total time from clone to full demo: **~90 minutes** (build) + **15 minutes** (evaluation)
