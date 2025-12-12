# Inception-of-Things (IoT)

A comprehensive Kubernetes project demonstrating K3s, K3d, ArgoCD, and GitOps workflows.

## 📚 Project Overview

This project consists of 4 parts demonstrating progressive Kubernetes concepts:

1. **Part 1 (P1)**: Multi-node K3s cluster with Vagrant
2. **Part 2 (P2)**: K3s server with 3 applications and Ingress
3. **Part 3 (P3)**: K3d cluster with ArgoCD and GitHub integration
4. **Bonus**: Local GitLab integration replacing GitHub

## 🎯 Architecture Strategy

### The Golden Rule
```
Parts with multiple machines → Nested VMs
Single environment → Direct on host
```

| Part | Vagrant? | Nested VM? | Why? |
|------|----------|------------|------|
| P1 | ✅ Yes | ✅ Yes (2 VMs) | Multi-node K3s cluster |
| P2 | ✅ Yes | ✅ Yes (1 VM) | Isolated environment |
| P3 | ❌ No | ❌ No | Runs on host (no Vagrant) |
| Bonus | ✅ Yes | ✅ Yes (1 VM) | GitLab isolation |

## 📁 Project Structure

```
inception-of-things/
├── README.md                        # This file
├── DEPLOYMENT_STRATEGY.md           # Complete technical strategy
├── EVALUATION_GUIDE.md              # Quick evaluation guide
├── ISO_PREPARATION_CHECKLIST.md    # .iso build checklist
├── PACKER_SUMMARY.md                # Packer build summary
├── VM_HIERARCHY.md                  # VM architecture explanation
│
├── packer/                          # Packer build for host VM
│   ├── iot-host-vm.pkr.hcl         # Packer template
│   ├── build.sh                     # Build automation
│   ├── http/
│   │   ├── user-data                # Ubuntu autoinstall
│   │   └── meta-data
│   └── README.md
│
├── p1/                              # Part 1: K3s + Vagrant (2 VMs)
│   ├── Vagrantfile
│   ├── scripts/
│   │   ├── install_k3s_server.sh
│   │   └── install_k3s_agent.sh
│   └── Makefile
│
├── p2/                              # Part 2: K3s + 3 Apps (1 VM)
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
│
├── p3/                              # Part 3: K3d + ArgoCD (Host)
│   ├── scripts/                     # NO Vagrantfile!
│   │   ├── setup.sh
│   │   ├── launch_k3d.sh
│   │   └── argocd.sh
│   ├── confs/
│   └── Makefile
│
└── bonus/                           # Bonus: GitLab (1 VM)
    ├── Vagrantfile
    ├── scripts/
    ├── confs/
    ├── validate.sh
    └── README.md
```

## 🚀 Quick Start

### Prerequisites

For evaluation, you need the **pre-built host VM** (created with Packer):

1. Boot from `iot-eval.iso` on SSD
2. All tools pre-installed (Vagrant, Docker, kubectl, k3d, Helm)
3. Nested virtualization enabled

### Evaluation Commands

```bash
# Clone this repository
git clone <this-repo>
cd inception-of-things

# Part 1: K3s cluster with 2 VMs
cd p1
make up
vagrant ssh frthierrS -c "kubectl get nodes"
vagrant destroy -f

# Part 2: K3s with 3 applications
cd ../p2
make up
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110  # Default → app3
vagrant destroy -f

# Part 3: K3d + ArgoCD (runs on host, no Vagrant)
cd ../p3
make up
curl http://localhost:8888
k3d cluster delete <cluster-name>

# Bonus: GitLab integration
cd ../bonus
vagrant up
curl http://192.168.56.150:8888
vagrant ssh -c "/vagrant/validate.sh"
vagrant destroy -f
```

## 📖 Documentation

### Core Documents

1. **[DEPLOYMENT_STRATEGY.md](DEPLOYMENT_STRATEGY.md)** - Complete implementation strategy
2. **[EVALUATION_GUIDE.md](EVALUATION_GUIDE.md)** - Step-by-step evaluation
3. **[ISO_PREPARATION_CHECKLIST.md](ISO_PREPARATION_CHECKLIST.md)** - .iso build guide
4. **[PACKER_SUMMARY.md](PACKER_SUMMARY.md)** - Packer build instructions
5. **[VM_HIERARCHY.md](VM_HIERARCHY.md)** - VM architecture explanation

## 🏗️ Building the Host VM (.iso)

### Using Packer (Recommended)

```bash
cd packer
./build.sh
```

**Output**: `output-ubuntu/iot-host-vm.ova` (~20 GB)
**Build time**: 45-60 minutes
**Then**: Convert .ova to bootable .iso using Clonezilla

See [PACKER_SUMMARY.md](PACKER_SUMMARY.md) for details.

## ⏱️ Time Estimates

With pre-built .iso:

| Part | Setup Time |
|------|-----------|
| P1 | ~3 min |
| P2 | ~2 min |
| P3 | ~1 min |
| Bonus | ~5 min |

**Total evaluation**: ~15-20 minutes

## 🔑 Key Technologies

- K3s, K3d, Vagrant, VirtualBox, Docker, ArgoCD, GitLab, kubectl, Helm

## 📋 System Requirements

- **CPUs**: 8 cores (for nested virtualization)
- **RAM**: 16 GB
- **Disk**: 100 GB
- **Nested Virtualization**: ENABLED

## 🚀 Ready for Evaluation!

1. Boot from `iot-eval.iso`
2. Clone this repository
3. Follow [EVALUATION_GUIDE.md](EVALUATION_GUIDE.md)
4. Run each part

**Total evaluation time**: 15-20 minutes ⚡

**Good luck! 🎯**
