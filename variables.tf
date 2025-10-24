variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}

variable "vm_user" {
  description = "Desired initial Cloud-Init username"
  type        = string
  default     = "deploy"  # Set a sensible default
}

variable "vm_password" {
  description = "Desired initial Cloud-Init password"
  type        = string
  sensitive   = true      # Mark as sensitive to hide from logs
}