terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://10.0.40.200:8006"
  api_token = var.proxmox_api_token
  insecure  = true # self-signed cert on Titan
}
