terraform {
  required_version = ">= 1.11"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}

# Ephemeral: decrypted on each run and never written to state or plan files.
ephemeral "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

# insecure: the host uses Proxmox's self-signed certificate.
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = ephemeral.sops_file.secrets.data["proxmox_api_token"]
  insecure  = true
}
