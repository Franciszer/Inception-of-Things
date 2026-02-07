# Part 1 — K3s two-node cluster with Vagrant

## Overview

Part 1 sets up a minimal K3s cluster using two Vagrant VMs:

| VM | Hostname | IP | Role |
|---|---|---|---|
| Server | `frthierrS` | `192.168.56.110` | K3s controller (control-plane) |
| Worker | `frthierrSW` | `192.168.56.111` | K3s agent |

Both VMs run Ubuntu 22.04 (Jammy). The server installs K3s in server mode and exposes its join token via HTTP. The worker fetches the token and joins the cluster as an agent.

## File structure

```
p1/
├── Vagrantfile                    # Defines the 2 VMs, IPs, resources
├── scripts/
│   ├── bootstrap_common.sh        # Shared setup (apt packages, disable apt-daily)
│   ├── install_k3s_server.sh      # Installs K3s server, publishes token
│   └── install_k3s_agent.sh       # Fetches token, installs K3s agent
└── test.sh                        # Automated eval checks (20 tests)
```

## Vagrant commands

```bash
# Start both VMs (runs provisioning on first boot)
vagrant up

# Check VM status
vagrant status

# SSH into server / worker
vagrant ssh frthierrS
vagrant ssh frthierrSW

# Stop VMs (preserves disk)
vagrant halt

# Destroy VMs completely
vagrant destroy -f

# Re-run provisioning scripts without rebuilding
vagrant provision
```

## Verifying the cluster

From the server VM:

```bash
vagrant ssh frthierrS
sudo kubectl get nodes -o wide
```

Expected output: both `frthierrs` and `frthierrsw` listed as `Ready`.

## Running the tests

```bash
cd p1
bash test.sh
```

The test script checks every point from the evaluation sheet: Vagrantfile structure, VM names, IPs, hostnames, K3s services, and cluster membership.
