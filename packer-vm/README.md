# IoT Base VM - Packer Build

This directory contains Packer configuration to build a base VM for the Inception-of-Things project.

## What's Included

The VM is pre-configured with:
- **Docker** - For K3d and containerized workloads
- **VirtualBox** - For running nested VMs (p1, p2)
- **Vagrant** - For managing nested VMs
- **kubectl** - Kubernetes CLI
- **Helm** - Kubernetes package manager
- **K3d** - Lightweight Kubernetes in Docker (for p3, bonus)
- **K3s install script** - For use in nested VMs

## VM Credentials

- **Username**: `iot`
- **Password**: `iot`
- User has passwordless sudo access

## Build Instructions

1. Install Packer:
```bash
# On Ubuntu/Debian
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer

# Or download from: https://www.packer.io/downloads
```

2. Initialize Packer plugins:
```bash
cd /home/frthierr/Workspace/Inception-of-Things/packer-vm
packer init .
```

3. Validate the configuration:
```bash
packer validate .
```

4. Build the VM (this will take 30-60 minutes):
```bash
packer build iot-vm.pkr.hcl
```

The output will be an OVA file: `iot-base-vm.ova`

## Importing the VM

1. Import the OVA in VirtualBox:
```bash
VBoxManage import iot-base-vm.ova
```

2. Or use the VirtualBox GUI: File > Import Appliance

## Using the VM

### For p1 and p2 (Vagrant inside):
```bash
# SSH into the VM
ssh iot@<vm-ip>

# Navigate to your project
cd /path/to/p1
vagrant up
```

### For p3 and bonus (K3d directly):
```bash
# SSH into the VM
ssh iot@<vm-ip>

# Create K3d cluster
k3d cluster create my-cluster

# Use kubectl
kubectl get nodes
```

## Customization

To modify the VM configuration:
- Edit `iot-vm.pkr.hcl` for VM specs (CPU, RAM, disk)
- Edit scripts in `scripts/` for software installation
- Edit `http/user-data` for user configuration

## Troubleshooting

If the build fails:
1. Check that VirtualBox is installed and working
2. Ensure you have enough disk space (50GB+)
3. Check Packer logs for specific errors
4. Verify ISO checksum matches

## Storage on SSD

To store the VM on SSD (like ychibani):
1. After importing, go to VM Settings > Storage
2. Move the VM disk to your SSD location
3. Or set VirtualBox default machine folder to SSD before importing
