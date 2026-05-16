# Proxmox VM Deployment with Terraform and Cloud-Init

[![Terraform](https://img.shields.io/badge/Terraform-3.0.2-%237B42BC.svg)](https://www.terraform.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE-blue.svg)](https://www.proxmox.com/)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange.svg)]()

Production-grade Terraform module for automated deployment of Cloud-Init ready VMs on Proxmox VE clusters. Features multi-VM scaling, SSH key authentication, and GitHub Actions CI/CD pipeline.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [What's Next](#whats-next)
- [License](#license)

---

## Overview

Deploy one or more Ubuntu Cloud-Init VMs on your Proxmox cluster with a single `terraform apply`. This project handles:

| Feature | Details |
|---------|---------|
| **Multi-VM Deployment** | Spin up 1–10 identical VMs with configurable `vm_count` |
| **Cloud-Init Auto-Config** | SSH keys, username, password injected automatically |
| **Resource Variables** | CPU, RAM, disk size all configurable without code changes |
| **GitHub Actions CI/CD** | Validate + plan on every push, deploy on main branch |
| **Debug Toggle** | Enable verbose logging via variable (disabled by default) |

---

## Architecture

```
                    GitHub Repository
                    (main.tf, variables.tf, deploy.yml)
                              |
                              v
                    GitHub Actions Runner (self-hosted)
                              |
                              |  terraform plan / apply
                              v
                    +---------------------------+
                    |      Proxmox VE Cluster   |
                    |                           |
                    |  +---------------------+  |
                    |  |  Clone Template     |  |
                    |  |  (ubuntu-24-ci)     |  |
                    |  +--------+------------+  |
                    |           |               |
                    |           v               |
                    |  +---------------------+  |
          +-------> |  Deploy VMs x N       |  |
          |         |  (VM template-1..N)   |  |
          |         +--------+--------------+  |
          |                  |                 |
          |       +----------+-----------+     |
          |       |  VM1 (virtio/net)    |     |
          |       |  VM2 (virtio/net)    |     |
          |       |  ...                 |     |
          |       |  VMN (virtio/net)    |     |
          |       +----------------------+     |
          v                                    v
     Developer / CI Script              Network (vmbr0)
     (get VM IPs via Proxmox API)       (DHCP assignment)
```

---

## Prerequisites

1. **Proxmox VE Cluster** — Version 7.x or 8.x
2. **Cloud-Init Template** — A prepared Ubuntu 24.04 Cloud-Init base template on your cluster
3. **Proxmox API Token** — Created with read/write permissions
4. **GitHub Repository** — With a self-hosted Actions runner connected to your Proxmox network
5. **SSH Key Pair** — Public key stored as a GitHub Secret

---

## Quick Start

### Step 1: Prepare Your Cloud-Init Template

Run these commands on your Proxmox host to create a reusable base template:

```bash
# Download Ubuntu 24.04 Cloud Image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloud-image-amd64.img

# Import to Proxmox storage
qm importdisk 9999 noble-server-cloud-image-amd64.img local-zfs

# Create a new VM for templating
qm create 9999 --name ubuntu-24-ci-template --memory 4096 --cores 4

# Attach the imported disk
qm set 9999 --scsi0 local-zfs:vm-9999-disk-0

# Add cloud-init disk
qm set 9999 --ide2 local-zfs:cloudinit

# Set boot order
qm set 9999 --boot c --bootdisk scsi0

# Enable qemu guest agent
qm set 9999 --agent enabled=1

# Start and configure the VM
qm start 9999
```

SSH into the VM and run cleanup:

```bash
# Install/update services
apt update && apt install -y cloud-init qemu-guest-agent
systemctl enable cloud-init
systemctl enable qemu-guest-agent

# Clear system identifiers
cloud-init clean --logs
rm -f /etc/machine-id
touch /etc/machine-id

# Shut down (DO NOT reboot)
poweroff
```

Convert to template:

```bash
qm template 9999
qm set 9999 --description "Ubuntu 24.04 Cloud-Init Base Template"
```

### Step 2: Configure GitHub Secrets

Add these secrets to your GitHub repository (**Settings → Secrets and variables → Actions**):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PM_API_URL` | Proxmox API endpoint | `https://proxmox.example.com:8006/api2/json` |
| `PM_API_TOKEN_ID` | API token ID | `root@pam!terraform` |
| `PM_API_TOKEN_SECRET` | API token secret (UUID) | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `SSH_PUBLIC_KEY` | Your SSH public key | `ssh-ed25519 AAAA... user@host` |
| `VM_PASSWORD` | Initial VM password | *(generate securely)* |

### Step 3: Deploy

```bash
# Clone and initialize
git clone https://github.com/<your-username>/proxmox-automation.git
cd proxmox-automation
terraform init

# Preview deployment
terraform plan -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
              -var="vm_password=your-strong-password"

# Deploy VMs
terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
                -var="vm_password=your-strong-password"
```

---

## Configuration

### Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_user` | `string` | `"deploy"` | Username for cloud-init |
| `vm_password` | `string` | *(required)* | Initial password (sensitive) |
| `ssh_public_key` | `string` | *(required)* | SSH public key for authentication |
| `vm_count` | `number` | `1` | Number of VMs to deploy (1–10) |
| `target_node` | `string` | `"pve1"` | Proxmox cluster node |
| `clone_source` | `string` | `"ubuntu-24-ci"` | Base template name |
| `storage_pool` | `string` | `"local-zfs"` | Storage pool for VM disks |
| `network_bridge` | `string` | `"vmbr0"` | Network bridge |
| `vm_cores` | `number` | `4` | CPU cores per VM |
| `vm_sockets` | `number` | `1` | CPU sockets per VM |
| `vm_memory` | `number` | `4096` | RAM per VM in MB |
| `vm_disk_size` | `number` | `32` | Disk size per VM in GB |
| `enable_debug_logging` | `bool` | `false` | Enable provider debug logging |

### Example: Deploy 3 VMs with Custom Resources

```bash
terraform apply \
  -var="vm_count=3" \
  -var="vm_cores=8" \
  -var="vm_memory=8192" \
  -var="vm_disk_size=64" \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var="vm_password=$(cat ~/.secrets/vm-password)"
```

---

## Usage

### Get Deployed VM Names

```bash
terraform output vm_names
# Output:
# vm_names = [
#   "ubuntu-24-ci-1",
#   "ubuntu-24-ci-2",
# ]
```

### SSH Into a VM

```bash
# After Terraform applies, get the VM IP from your Proxmox GUI or DHCP server
ssh deploy@<VM_IP_ADDRESS>
```

### Destroy All Deployed VMs

```bash
terraform destroy -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
                  -var="vm_password=your-strong-password"
```

---

## Troubleshooting

### VM Fails to Boot After Clone

**Symptom:** VM shows "no bootable medium" in Proxmox GUI

**Fix:** Verify the clone template has a valid OS disk (not just cloud-init disk). Run:
```bash
qm list
# Check that your template (e.g., ubuntu-24-ci) shows a disk under the DISK field
```

### Cloud-Init Configuration Not Applied

**Symptom:** VM boots but SSH key/password injection doesn't work

**Fix:**
1. Confirm the template has `cloud-init` installed: `cloud-init --version`
2. Ensure the cloud-init disk slot is `ide2` (reserved by Proxmox)
3. Check VM logs: `qm terminal <VM_ID>` → examine `/var/log/cloud-init.log`

### API Authentication Errors

**Symptom:** `Error: POST https://.../access/tokens: 401 Unauthorized`

**Fix:**
1. Verify `PM_API_TOKEN_ID` and `PM_API_TOKEN_SECRET` are set correctly in GitHub Secrets
2. Confirm the token has **Read/Write** permissions on the target node
3. Check token ID format: `<user>@<realm>!<token-name>` (e.g., `root@pam!terraform`)

### Debug Logging Enabled in Production

**Symptom:** Rapid disk growth from `terraform-plugin-proxmox.log`

**Fix:** Set `enable_debug_logging = false` in your `.tfvars` or CLI variables. The log is disabled by default.

---

## What's Next

Suggested enhancements for production use:

1. **Dynamic IP Output** — Add a post-deploy script to fetch VM IPs from Proxmox API and output them
2. **Custom Templates Per OS** — Add variables for Ubuntu 22.04, Debian, or RHEL templates
3. **Floating IP Support** — Auto-assign and track IPs via DHCP lease parsing
4. **Snapshot Before Deploy** — Create a pre-deploy snapshot of the base template for rollback
5. **Grafana Dashboard** — Monitor Proxmox cluster health alongside deployed VMs

---

## License

[MIT License](LICENSE) — Feel free to use this for your own projects.

---

## Author

**Nicolas Teixeira** — [GitHub](https://github.com/nicolasnkGH) | DevOps & Cloud Engineer