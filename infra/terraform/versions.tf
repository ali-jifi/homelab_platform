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
  }
}

# Endpoint and token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN.
# insecure: the host uses Proxmox's self-signed certificate.
provider "proxmox" {
  insecure = true
}
