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
        address = "10.0.40.3/24"
        gateway = "10.0.40.1"
      }
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.homelab_vlan_id
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
        address = "10.0.40.4/24"
        gateway = "10.0.40.1"
      }
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.homelab_vlan_id
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

resource "proxmox_virtual_environment_container" "unifi" {
  node_name     = "apollo"
  vm_id         = 202
  started       = true
  start_on_boot = true
  unprivileged  = false

  lifecycle {
    ignore_changes = [features, device_passthrough]
  }

  initialization {
    hostname = "unifi"

    ip_config {
      ipv4 {
        address = "10.0.40.5/24"
        gateway = "10.0.40.1"
      }
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "BC:24:11:5F:02:22"
    vlan_id     = var.homelab_vlan_id
  }

  disk {
    datastore_id = "local-lvm"
    size         = 32
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_lxc_template.id
    type             = "debian"
  }
}
