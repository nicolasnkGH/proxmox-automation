terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">=2.9.11"
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
    slot    = 0
    size    = "250G"
    storage = "local-zfs"
    type    = "scsi"
  }

  os_type    = "cloud-init"
  ipconfig0  = "ip=dhcp"
  agent      = 1
  boot       = "order=scsi0;ide0"

  # Using ci_config to pass user data
    ci_config {
        user       = "test"
        password   = "abc123"
        ssh_keys   = [var.ssh_public_key] # Note the square brackets for a list
        ssh_pwauth = true                 # Ensures password login remains enabled
  }

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
} 

