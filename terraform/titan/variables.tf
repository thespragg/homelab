variable "proxmox_api_token" {
  description = "Proxmox API token in the format USER@REALM!TOKENID=SECRET"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into new containers at creation time (Ansible's common role manages authorized_keys afterwards)."
  type        = list(string)
  default = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDybCE37umMe9ncx/tui+ahFL5cFCPXfY8GElM9ib0HM alistair.spragg@gmail.com",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIgl6d6O1IfW9QO/0m7n0pUsxehSSz660IbBOOPFfzYB thespragg@alistair-desktop",
  ]
}
