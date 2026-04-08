resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = "apollo"
  vm_id     = 100

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  # LAN - vtnet0, VLAN 20, 10.0.20.0/24
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  # WAN - vtnet1, untagged, temporary internet via Archer C6 during build phase
  # At cutover: add vlan_id = 10
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  started         = false
  stop_on_destroy = true

  operating_system {
    type = "other" # FreeBSD
  }
}
