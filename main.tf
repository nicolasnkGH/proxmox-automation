terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      # FIX: Using a stable 2.x version to avoid v2.9.14 crash and non-existent v3.x
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

  cores       = 4
  sockets     = 1
  memory      = 4096

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # --- FIX 1: MAIN OS DISK (requires size) ---
  disk {
    slot    = 0
    size    = "32G"
    storage = "local-zfs"
    type    = "scsi"
  }

  os_type    = "cloud-init"
  ipconfig0  = "ip=dhcp"
  agent      = 1
  boot       = "order=scsi0;ide0"

  # --- FIX 3: Using Individual Arguments from Reference (ci_config was flagged as unsupported) ---
  ci_config {
    user_data = <<-EOT
      #cloud-config
      users:
        - name: test
          groups: wheel
          sudo: ALL=(ALL) NOPASSWD:ALL
          shell: /bin/bash
          passwd: abc123
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      ssh_pwauth: True
      chpasswd: { expire: false }
    EOT
  }
  
  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
}