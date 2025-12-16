# Packer template for Inception-of-Things Evaluation VM
# Creates a VM with all tools pre-installed for fast SSD deployment

packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

# Variables
variable "vm_name" {
  type    = string
  default = "iot-eval-vm"
}

variable "cpus" {
  type    = number
  default = 12
}

variable "memory" {
  type    = number
  default = 17084  # ~17 GB
}

variable "disk_size" {
  type    = number
  default = 102400  # 100 GB
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
}

variable "ssh_username" {
  type    = string
  default = "ychibani"
}

variable "ssh_password" {
  type    = string
  default = "2700"
}

# Source configuration
source "virtualbox-iso" "ubuntu" {
  vm_name              = var.vm_name
  guest_os_type        = "Ubuntu_64"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum

  # VM Hardware - match existing VM
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  hard_drive_interface = "sata"
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nested-hw-virt", "on"],
    ["modifyvm", "{{.Name}}", "--nested-paging", "on"],
    ["modifyvm", "{{.Name}}", "--vtxvpid", "on"],
    ["modifyvm", "{{.Name}}", "--audio", "none"]
  ]

  headless = true

  # Boot configuration for Ubuntu Server autoinstall
  boot_wait            = "3s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds='nocloud-net;s=http://{{.HTTPIP}}:{{.HTTPPort}}/' ---<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]

  # HTTP server for autoinstall
  http_directory       = "http"

  # SSH configuration
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = "60m"
  ssh_handshake_attempts = 100

  # Shutdown
  shutdown_command     = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Output
  output_directory     = "output-iot-eval"
  format               = "ova"

  # Guest additions
  guest_additions_mode = "upload"
  guest_additions_path = "VBoxGuestAdditions.iso"
}

# Build
build {
  sources = ["source.virtualbox-iso.ubuntu"]

  # Wait for cloud-init
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init...'",
      "timeout 300 cloud-init status --wait || echo 'Cloud-init timeout, continuing...'",
      "sleep 30"
    ]
  }

  # System update
  provisioner "shell" {
    inline = [
      "echo 'Updating system...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y"
    ]
  }

  # Essential tools
  provisioner "shell" {
    inline = [
      "echo 'Installing essential tools...'",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl wget git vim nano jq net-tools openssh-server ca-certificates gnupg lsb-release software-properties-common apt-transport-https"
    ]
  }

  # VirtualBox
  provisioner "shell" {
    expect_disconnect = true
    inline = [
      "echo 'Installing VirtualBox...'",
      "wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib\" | sudo tee /etc/apt/sources.list.d/virtualbox.list",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-7.0 linux-headers-$(uname -r) dkms",
      "sudo usermod -aG vboxusers ${var.ssh_username}"
    ]
  }

  # Vagrant
  provisioner "shell" {
    inline = [
      "echo 'Installing Vagrant...'",
      "wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vagrant"
    ]
  }

  # Docker
  provisioner "shell" {
    inline = [
      "echo 'Installing Docker...'",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ${var.ssh_username}",
      "sudo systemctl enable docker",
      "sudo systemctl start docker"
    ]
  }

  # kubectl
  provisioner "shell" {
    inline = [
      "echo 'Installing kubectl...'",
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      "rm kubectl"
    ]
  }

  # k3d
  provisioner "shell" {
    inline = [
      "echo 'Installing k3d...'",
      "curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    ]
  }

  # Helm
  provisioner "shell" {
    inline = [
      "echo 'Installing Helm...'",
      "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    ]
  }

  # Enable nested virtualization
  provisioner "shell" {
    inline = [
      "echo 'Configuring nested virtualization...'",
      "echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm-intel.conf",
      "echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm-amd.conf",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf"
    ]
  }

  # Pre-cache Vagrant boxes
  provisioner "shell" {
    inline = [
      "echo 'Pre-downloading Vagrant boxes (this takes time)...'",
      "sudo -u ${var.ssh_username} vagrant box add ubuntu/focal64 --provider virtualbox || true",
      "sudo -u ${var.ssh_username} vagrant box add generic/ubuntu2004 --provider virtualbox || true"
    ]
  }

  # Pre-cache Docker images
  provisioner "shell" {
    pause_before = "10s"
    timeout = "30m"
    inline = [
      "echo 'Pre-downloading Docker images...'",
      "sudo docker pull rancher/k3s:latest",
      "sudo docker pull rancher/k3s:v1.31.5-k3s1",
      "sudo docker pull ghcr.io/k3d-io/k3d-tools:5.8.3",
      "sudo docker pull ghcr.io/k3d-io/k3d-proxy:5.8.3",
      "sudo docker pull quay.io/argoproj/argocd:latest",
      "sudo docker pull wil42/playground:v1",
      "sudo docker pull wil42/playground:v2",
      "sudo docker pull nginx:alpine"
    ]
  }

  # Enable SSH
  provisioner "shell" {
    inline = [
      "echo 'Configuring SSH...'",
      "sudo systemctl enable ssh",
      "sudo systemctl start ssh"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean -y",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*"
    ]
  }

  # Create README
  provisioner "shell" {
    inline = [
      "cat > /home/${var.ssh_username}/README.txt << 'EOF'",
      "=================================================",
      "Inception-of-Things Evaluation VM",
      "=================================================",
      "",
      "Username: ${var.ssh_username}",
      "Password: ${var.ssh_password}",
      "",
      "Pre-installed tools:",
      "  - VirtualBox 7.0 (nested virtualization enabled)",
      "  - Vagrant",
      "  - Docker",
      "  - kubectl",
      "  - k3d",
      "  - Helm",
      "",
      "Pre-cached resources:",
      "  - Vagrant boxes: ubuntu/focal64, generic/ubuntu2004",
      "  - Docker images: k3s, k3d, argocd, gitlab, playground",
      "",
      "To get started:",
      "  1. Clone your Inception-of-Things repo",
      "  2. cd to p1, p2, p3, or bonus",
      "  3. Run: vagrant up (for p1, p2, bonus)",
      "  4. Or run setup scripts (for p3)",
      "",
      "=================================================",
      "EOF"
    ]
  }
}
