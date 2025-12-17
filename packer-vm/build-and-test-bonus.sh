#!/bin/bash
# Complete rebuild and test script for Inception-of-Things

set -e
cd /media/frthierr/Vms/packer-iot

echo "=== STEP 1: Building VM with Packer (60-90 min) ==="
rm -rf output-iot-eval
./packer init iot-eval.pkr.hcl
./packer validate iot-eval.pkr.hcl
./packer build iot-eval.pkr.hcl

echo "=== STEP 2: Cleaning up old VM ==="
VBoxManage unregistervm iot-eval-vm --delete 2>/dev/null || true

echo "=== STEP 3: Importing new VM ==="
VBoxManage import output-iot-eval/iot-eval-vm.ova --vsys 0 --vmname "iot-eval-vm"

echo "=== STEP 4: Configuring networking ==="
VBoxManage modifyvm iot-eval-vm --natpf1 "ssh,tcp,,2222,,22"

echo "=== STEP 5: Starting VM ==="
VBoxManage startvm iot-eval-vm --type headless

echo "=== STEP 6: Waiting for SSH ==="
MAX_WAIT=120
ELAPSED=0
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p 2222 ychibani@localhost "echo 'SSH ready'" 2>/dev/null; do
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "ERROR: SSH not available after ${MAX_WAIT}s"
        exit 1
    fi
    echo "Waiting for SSH... (${ELAPSED}s/${MAX_WAIT}s)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done
echo "SSH is ready!"

echo "=== STEP 7: Testing bonus deployment ==="
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -p 2222 ychibani@localhost << 'EOSSH'
cd ~/Inception-of-Things/bonus/scripts
echo "=== Starting bonus deployment ==="
./run.sh

echo "=== Bonus deployment complete! ==="
EOSSH

echo ""
echo "✓ ALL DONE!"
echo "SSH to VM: ssh -p 2222 ychibani@localhost"
echo "Check bonus: ssh -p 2222 ychibani@localhost 'cd Inception-of-Things/bonus && kubectl get pods -A'"
