terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      # Using a known stable/RC version to avoid crashes
      version = "3.0.2-rc05"
    }
  }
}

provider "proxmox" {
  pm_tls_insecure = true
  pm_log_enable   = var.enable_debug_logging
  pm_log_file     = "terraform-plugin-proxmox.log"
  pm_debug        = var.enable_debug_logging
  pm_log_levels = {
    _default    = var.enable_debug_logging ? "debug" : "info"
    _capturelog = ""
  }
}

resource "proxmox_vm_qemu" "ubuntu-24-ci" {
  count       = var.vm_count
  name        = "${var.clone_source}-${count.index + 1}"
  target_node = var.target_node
  clone       = var.clone_source
  full_clone  = true

  # CPU Configuration
  cpu {
    cores   = var.vm_cores
    sockets = var.vm_sockets
  }
  memory = var.vm_memory

  # Network
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Main OS Disk
  disk {
    slot    = "scsi0"
    size    = "${var.vm_disk_size}G"
    storage = var.storage_pool
    type    = "disk"
  }

  # Cloud-Init Drive
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage_pool
  }

  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"
  agent   = 1
  boot    = "order=scsi0"

  # Cloud-Init Credentials & SSH Key
  ciuser     = var.vm_user
  cipassword = var.vm_password
  sshkeys    = var.ssh_public_key

  # Serial Console for Cloud-Init Compatibility
  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }
}

# Outputs
output "vm_names" {
  description = "Names of the deployed VMs"
  value       = proxmox_vm_qemu.ubuntu-24-ci[*].name
}

output "ssh_command_template" {
  description = "SSH command template to connect to deployed VMs (replace <IP> after deployment)"
  value       = "ssh ${var.vm_user}@<VM_IP_ADDRESS>"
}

output "vm_count" {
  description = "Number of VMs deployed"
  value       = var.vm_count
}