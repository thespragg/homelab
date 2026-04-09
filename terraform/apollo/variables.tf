variable "proxmox_api_token" {
  description = "Proxmox API token in the format USER@REALM!TOKENID=SECRET"
  type        = string
  sensitive   = true
}

variable "opnsense_img_url" {
  description = "Direct download URL for the pre-configured OPNsense image (bz2 compressed)."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used to connect to apollo for provisioning."
  type        = string
  default     = "~/.ssh/id_ed25519"
}
