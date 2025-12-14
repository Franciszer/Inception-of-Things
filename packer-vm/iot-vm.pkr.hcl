packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "iot-base-vm"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 50000
}

source "virtualbox-iso" "ubuntu" {
  guest_os_type = "Ubuntu_64"
  iso_url       = "https://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/ubuntu-20.04.1-legacy-server-amd64.iso"
  iso_checksum  = "sha256:f11bda2f2caed8f420802b59f382c25160b114ccc665dbac9c5046e7fceaced2"

  vm_name              = var.vm_name
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  hard_drive_interface = "sata"

  ssh_username         = "iot"
  ssh_password         = "iot"
  ssh_timeout          = "60m"
  ssh_handshake_attempts = 100

  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "<esc><wait>",
    "<enter><wait>",
    "/install/vmlinuz<wait>",
    " initrd=/install/initrd.gz",
    " auto-install/enable=true",
    " debconf/priority=critical",
    " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<wait>",
    " -- <wait>",
    "<enter><wait>"
  ]

  shutdown_command = "echo 'iot' | sudo -S shutdown -P now"

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--ioapic", "on"],
    ["modifyvm", "{{.Name}}", "--natdnshostresolver1", "on"],
    ["modifyvm", "{{.Name}}", "--natdnsproxy1", "on"],
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{.Name}}", "--vram", "128"]
  ]

  export_opts = [
    "--manifest",
    "--vsys", "0",
    "--description", "IoT Base VM with all tools pre-installed",
    "--version", "1.0.0"
  ]

  format = "ova"
}

build {
  sources = ["source.virtualbox-iso.ubuntu"]

  provisioner "shell" {
    execute_command = "echo 'iot' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "scripts/01-update.sh",
      "scripts/02-docker.sh",
      "scripts/03-vagrant-vbox.sh",
      "scripts/04-k8s-tools.sh",
      "scripts/05-cleanup.sh"
    ]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "checksums.txt"
  }
}
