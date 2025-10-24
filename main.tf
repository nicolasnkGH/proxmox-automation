terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      # Check each version for syntax updates
      version = "3.0.2-rc05"
    }
  }
}

provider "proxmox" {
  pm_tls_insecure = true
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

resource "proxmox_vm_qemu" "ubuntu-24-ci" {
  count = 1
  name        = "ubuntu-24-ci-${count.index + 1}"
  target_node = "pve1"
  clone       = "ubuntu-24-ci"
  full_clone  = true
  scsihw      = "virtio-scsi-single"
  cpu {
    cores     = 4  # Cores is correctly here
    sockets   = 1  # FIX: Sockets moved inside the cpu block
  }
  memory      = 4096

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # --- FIX 1: MAIN OS DISK (requires size) ---
  disk {
    slot    = "scsi0"
    size    = "32G"
    storage = "local-zfs"
    type    = "disk"
  }
#   --- FIX 2: CLOUD-INIT DISK ---
  disk {
    slot    = "ide2"       
    type    = "cloudinit"
    storage = "local-zfs" 
  }

  os_type    = "cloud-init"
  ipconfig0  = "ip=dhcp"
  agent      = 1
  boot       = "order=scsi0"

  ciuser     = var.vm_user
  cipassword = var.vm_password
  sshkeys    = var.ssh_public_key
  
  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
}