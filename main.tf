terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      # FIX: Using a stable 2.x version to avoid v2.9.14 crash and non-existent v3.x
      version = "~>2.9" 
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

resource "proxmox_vm_qemu" "rhel9_test" {
  count = 1
  name        = "rhel9-vm-${count.index + 1}"
  target_node = "pve1"
  clone       = "rhel-terraform"
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
    size    = "250G"
    storage = "local-zfs"
    type    = "scsi"
  }
  
  os_type    = "cloud-init"
  ipconfig0  = "ip=dhcp"
  agent      = 1
  boot       = "order=scsi0;ide0"

  # --- FIX 3: Using Individual Arguments from Reference (ci_config was flagged as unsupported) ---
  ciuser     = "test"                 
  cipassword = "abc123"             
  sshkeys    = var.ssh_public_key
  
  # Note: The ssh_pwauth setting is now implicitly handled by Proxmox since 
  # you set a password, but if you hit SSH password issues, you may need 
  # to switch to ci_user_data raw YAML. We start here.

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
}