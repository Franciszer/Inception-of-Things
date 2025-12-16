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

echo "=== STEP 6: Waiting for SSH (120s) ==="
sleep 120

echo "=== STEP 7: Copying repo and testing bonus ==="
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -p 2222 ychibani@localhost << 'EOSSH'
cd ~
# Copy from host shared folder or git clone
cp -r /vagrant/Inception-of-Things . 2>/dev/null || git clone /home/frthierr/Workspace/Inception-of-Things || echo "Manual copy needed"

cd Inception-of-Things/bonus
echo "=== Starting bonus vagrant up ==="
vagrant up --provider=virtualbox

echo "=== Bonus deployment complete! ==="
EOSSH

echo ""
echo "✓ ALL DONE!"
echo "SSH to VM: ssh -p 2222 ychibani@localhost"
echo "Check bonus: ssh -p 2222 ychibani@localhost 'cd Inception-of-Things/bonus && vagrant status'"
