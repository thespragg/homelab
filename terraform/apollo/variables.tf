variable "proxmox_api_token" {
  description = "Proxmox API token in the format USER@REALM!TOKENID=SECRET"
  type        = string
  sensitive   = true
}

variable "proxmox_host" {
  description = "Management address used by Terraform and SSH to reach Apollo."
  type        = string
  default     = "10.0.10.2"
}

variable "opnsense_img_url" {
  description = "Direct download URL for the installed OPNsense disk image (bz2 compressed)."
  type        = string
  sensitive   = true
}

variable "opnsense_img_sha256" {
  description = "SHA-256 checksum of the compressed installed OPNsense image."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used to connect to apollo for provisioning."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key injected into LXC containers at creation."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "management_vlan_id" {
  description = "VLAN ID for infrastructure management."
  type        = number
  default     = 10
}

variable "lan_vlan_id" {
  description = "VLAN ID for the LAN network."
  type        = number
  default     = 20
}

variable "iot_vlan_id" {
  description = "VLAN ID for IoT devices."
  type        = number
  default     = 30
}

variable "homelab_vlan_id" {
  description = "VLAN ID for homelab services."
  type        = number
  default     = 40
}

variable "wan1_vlan_id" {
  description = "VLAN ID for the active WAN connection."
  type        = number
  default     = 901
}

variable "wan2_vlan_id" {
  description = "VLAN ID reserved for the second WAN connection."
  type        = number
  default     = 902
}

variable "debian_lxc_template_url" {
  description = "URL for the Debian LXC template on the Proxmox template mirror."
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}
