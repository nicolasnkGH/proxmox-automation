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
}

resource "proxmox_vm_qemu" "rhel9_test" {
  name        = "rhel9-test-vm"
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

  # --- FIX 2: CLOUD-INIT DISK (requires slot, no size) ---
  disk {
    slot    = 1             # Use a unique slot number (e.g., 1 or 2)
    type    = "cloudinit"
    storage = "local-zfs"
    # size is omitted for cloudinit disk
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