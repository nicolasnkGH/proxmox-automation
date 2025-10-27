# Proxmox VM Deployment with Terraform and Cloud-Init

This project demonstrates how to automate the deployment of a Virtual Machine (VM) on Proxmox VE using **Terraform** for Infrastructure as Code (IaC) and **Cloud-Init** for initial configuration.

We utilized a **base Ubuntu Cloud Image** (though the troubleshooting involved RHEL, this summary reflects the successful general process) and configured the entire stack to run from a GitHub Actions workflow.

---

## Prerequisites

Before starting, ensure you have:

1.  A functioning Proxmox VE Cluster.
2.  A GitHub repository with a configured self-hosted GitHub Actions runner pointing to the Proxmox environment.
3.  Proxmox API credentials (Token ID and Secret) stored securely as GitHub Secrets (`PM_API_TOKEN_ID`, `PM_API_TOKEN_SECRET`, etc.).
4.  An SSH Public Key stored as a GitHub Secret (`SSH_PUBLIC_KEY`).

---

## 1. Cloud Image Preparation (Base Template Creation)

The key to stable deployment is a clean, compliant base template.

### A. Create the Base Cloud-Init Image

1.  **Download Image:** Download a standard Ubuntu Cloud Image (e.g., Ubuntu 24.04 LTS cloud image).
2.  **Import to Proxmox:** Import the QCOW2 file into your desired storage (e.g., `local-zfs`).
3.  **Create VM:** Create a new VM and attach the imported disk.

### B. Template Internal Cleanup (Crucial Fixes)

Before converting the VM, essential cleanup and service fixes must be performed inside the Guest OS:

1.  **Install/Enable Services:** Ensure `cloud-init` and the optional `qemu-guest-agent` are installed and enabled.
2.  **Configure User:** Ensure a base user is configured (e.g., the default user or a custom one).
3.  **Clean System Identifiers:** Clear unique system identifiers and Cloud-Init history:
    ```bash
    sudo cloud-init clean --logs
    sudo rm -f /etc/machine-id
    sudo touch /etc/machine-id
    ```
4.  **Finalize:** Shut down the VM. **Do not reboot** before converting.

### C. Convert to Template

1.  In the Proxmox GUI, right-click the powered-off VM.
2.  Select **More** $\rightarrow$ **Convert to Template** (e.g., named `ubuntu-24-ci`).

---

## 2. Terraform Configuration (`main.tf`)

The Terraform code defines the VM structure and injects the user configuration.

### A. Provider and Stability

The configuration uses a specific version constraint to avoid known bugs and explicitly uses variables for security:

```terraform
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      # Using a known stable/RC version to avoid crashes
      version = "3.0.2-rc05" 
    }
  }
}
# Connection details are automatically read from environment variables (secrets)
provider "proxmox" {
  pm_tls_insecure = true
}
```

### B. VM Resource and Cloud-Init Injection

The resource defines the VM and uses the individual arguments (ciuser, cipassword, sshkeys) which were found to be the only syntactically supported method for this version:

```terraform
resource "proxmox_vm_qemu" "ubuntu-24-ci" {
  name        = "ubuntu-24-ci-${count.index + 1}"
  clone       = "ubuntu-24-ci"

  # Hardware Fixes
  scsihw      = "virtio-scsi-single"
  cpu { cores = 4; sockets = 1 } 

  # Disk Definition
  disk { slot = "scsi0"; size = "32G"; type = "disk"; storage = "local-zfs" }
  # The Cloud-Init drive is automatically managed via the template and OS_type

  # Cloud-Init Injection (References variables defined in variables.tf)
  os_type     = "cloud-init"
  ipconfig0   = "ip=dhcp"
  ciuser      = var.vm_user
  cipassword  = var.vm_password
  sshkeys     = var.ssh_public_key
  # ... other essential hardware (network, serial, boot) ...
}
```
## 3. GitHub Actions Workflow (deploy.yml)

The workflow securely passes the sensitive configuration values to Terraform.

1. Secure Variables: Secrets are loaded into environment variables (env: block).

2. Command Execution: The values are passed as Terraform variables using the -var flag.

```YAML
# deploy.yml (Snippet for Plan Step)

      - name: Terraform Plan
        env:
            SSH_PUBLIC_KEY: ${{ secrets.SSH_PUBLIC_KEY }}
            VM_PASSWORD: ${{ secrets.VM_PASSWORD }}
        run: terraform plan -var="ssh_public_key=$SSH_PUBLIC_KEY" -var="vm_user=test" -var="vm_password=$VM_PASSWORD"
```

## Usage

Ensure all secrets (PM_API_..., VM_PASSWORD, SSH_PUBLIC_KEY) are set in your GitHub repository.

1. Commit the Terraform files (main.tf, variables.tf) and the workflow file (deploy.yml).

2. Go to the Actions tab in GitHub and manually run the workflow.

3. Upon completion, the VM will be available and configurable using the injected username (test) and SSH key.
