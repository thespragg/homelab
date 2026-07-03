resource "proxmox_virtual_environment_container" "paperless" {
  node_name = "pve"
  vm_id     = 123

  unprivileged = true

  features {
    nesting = true
    keyctl  = true
  }

  operating_system {
    type             = "debian"
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "ContainerStorage"
    size         = 16
  }

  # Primary LAN (vmbr0, 10.0.40.0/24) - the existing 10.10.0.0/24 internal
  # network (postgres/grafana/caddy/osrs-clan-bot/immich's LXC) is legacy
  # and currently unreachable; new services go on 10.0.40.0/24 instead.
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "paperless"

    ip_config {
      ipv4 {
        address = "10.0.40.30/24"
        gateway = "10.0.40.1"
      }
    }

    dns {
      servers = ["8.8.8.8", "8.8.4.4"]
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  started = true

  tags = ["ansible"]
}
