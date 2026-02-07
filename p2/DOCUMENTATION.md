# Part 2 — K3s and three simple applications

## Overview

Part 2 deploys a single-node K3s cluster running three web applications,
routed by HOST-based Ingress via Traefik (K3s's built-in ingress controller).

| Host header | Application | Replicas | Description |
|---|---|---|---|
| `app1.com` | app1 | 1 | Routed when Host is `app1.com` |
| `app2.com` | app2 | 3 | Routed when Host is `app2.com` |
| *(any other)* | app3 | 1 | Catch-all default |

**VM**: `frthierrS` — IP `192.168.56.110` — Ubuntu 22.04 (Jammy)

## File structure

```
p2/
├── Vagrantfile                 # 1 VM definition (name, IP, resources)
├── confs/
│   └── app.yaml                # K8s manifests (deployments, services, ingress)
├── scripts/
│   └── bootstrap_vm.sh         # Installs K3s, applies app.yaml
├── test.sh                     # Automated eval checks
└── DOCUMENTATION.md
```

## How it works

1. **Vagrant** creates a VM with a private network IP (`192.168.56.110`)
2. The `file` provisioner copies `confs/app.yaml` into the guest at `/tmp/app.yaml`
3. `bootstrap_vm.sh` installs K3s in server mode, waits for the node and Traefik
   to be ready, then runs `kubectl apply -f /tmp/app.yaml`
4. The manifest creates 3 Deployments + 3 Services + 1 Ingress in the `default`
   namespace
5. Traefik reads the Ingress rules and routes traffic based on the `Host` header

## Vagrant commands

```bash
# Start the VM (runs provisioning on first boot)
vagrant up

# Check VM status
vagrant status

# SSH into the VM
vagrant ssh frthierrS

# Stop the VM (preserves disk)
vagrant halt

# Destroy the VM completely
vagrant destroy -f

# Re-run provisioning without rebuilding
vagrant provision
```

## Verifying the setup

From inside the VM:

```bash
vagrant ssh frthierrS

# Cluster status
sudo kubectl get nodes -o wide

# All resources (should show 3 deployments, 3 services, pods)
sudo kubectl get all

# Ingress rules
sudo kubectl get ingress
sudo kubectl describe ingress iot-ingress
```

## Testing the Ingress routing

```bash
# From the VM host (or inside the VM with localhost):
curl -H 'Host: app1.com' http://192.168.56.110/    # -> app1 responds
curl -H 'Host: app2.com' http://192.168.56.110/    # -> app2 responds
curl http://192.168.56.110/                          # -> app3 (default)
```

Each response is JSON from `ealen/echo-server`. The `HOSTNAME` field in the
response shows the pod name (e.g. `app1-xxxxx`), confirming which application
handled the request.

## Running the tests

```bash
cd p2
bash test.sh
```

The test script verifies the full setup: Vagrantfile structure, VM name and IP,
K3s service, cluster nodes, all 3 deployments with correct replica counts,
Ingress rules, and HOST-based curl routing.
