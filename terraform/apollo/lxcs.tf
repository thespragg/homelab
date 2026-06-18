locals {
  ssh_public_key = trimspace(file(var.ssh_public_key_path))
}

resource "proxmox_virtual_environment_container" "adguard" {
  node_name = "apollo"
  vm_id     = 200
  started   = true

  initialization {
    hostname = "adguard"

    ip_config {
      ipv4 {
        address = "10.0.20.3/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.lan_vlan_id
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 256
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_lxc_template.id
    type             = "debian"
  }
}

resource "proxmox_virtual_environment_container" "caddy" {
  node_name = "apollo"
  vm_id     = 201
  started   = true

  initialization {
    hostname = "caddy"

    ip_config {
      ipv4 {
        address = "10.0.20.4/24"
        gateway = "10.0.20.1"
      }
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.lan_vlan_id
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 256
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_lxc_template.id
    type             = "debian"
  }
}
