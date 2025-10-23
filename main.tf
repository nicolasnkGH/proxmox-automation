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
  clone       = "RHEL-9.6-DHCP-Locked-9.6-ci"          # change to your template name
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
  ciuser     = "test"                 # change to your desired initial user
  cipassword = "abc123"             # change to your desired initial user password
  ipconfig0  = "ip=dhcp"
}
