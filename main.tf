terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">=3.0.2"
    }
  }
}

provider "proxmox" {
  # All sensitive information is read from environment variables:
  # PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET
  pm_tls_insecure = true
}
resource "proxmox_vm_qemu" "rhel9_test" {
  name        = "rhel9-test-vm"
  target_node = "pve1"                    # change to your node name
  clone       = "rhel-terraform"          # change to your template name
  full_clone  = true

  cores       = 4
  sockets     = 1
  memory      = 4096

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
  slot    = "ide0"
  type    = "cloudinit"
  storage = "local-zfs"
}

  os_type    = "cloud-init"
  ipconfig0  = "ip=dhcp"
  agent      = 1
  boot       = "order=scsi0;ide0"

  ci_config {
    user       = "test"
    password   = "abc123"
    ssh_keys   = [var.ssh_public_key] 
    ssh_pwauth = true 
  }

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
} 

