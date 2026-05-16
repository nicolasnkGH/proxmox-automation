variable "ssh_public_key" {
  description = "SSH public key for cloud-init authentication"
  type        = string
  sensitive   = false
}

variable "vm_password" {
  description = "Initial password for the cloud-init user account"
  type        = string
  sensitive   = true
}

variable "vm_user" {
  description = "Username for the cloud-init initial user account"
  type        = string
  default     = "deploy"
}

variable "vm_count" {
  description = "Number of VMs to deploy"
  type        = number
  default     = 1
  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10."
  }
}

variable "target_node" {
  description = "Proxmox cluster node to deploy VMs on"
  type        = string
  default     = "pve1"
}

variable "clone_source" {
  description = "Name of the Proxmox VM template to clone"
  type        = string
  default     = "ubuntu-24-ci"
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disks and cloud-init drive"
  type        = string
  default     = "local-zfs"
}

variable "network_bridge" {
  description = "Proxmox network bridge to attach VMs to"
  type        = string
  default     = "vmbr0"
}

variable "vm_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 4
}

variable "vm_sockets" {
  description = "Number of CPU sockets per VM"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "RAM allocated to each VM in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size for each VM in GB"
  type        = number
  default     = 32
}

variable "enable_debug_logging" {
  description = "Enable verbose Terraform provider debug logging (disable for production)"
  type        = bool
  default     = false
}