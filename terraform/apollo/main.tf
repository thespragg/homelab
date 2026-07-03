terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.100"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${var.proxmox_host}:8006"
  api_token = var.proxmox_api_token
  insecure  = true # self-signed cert on fresh Proxmox install
}
