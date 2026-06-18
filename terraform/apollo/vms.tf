resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = "apollo"
  vm_id     = 100

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  # Keep this order and the MAC addresses stable: the custom image assigns interfaces
  # by their vtnet names. Proxmox handles VLAN tags, so OPNsense sees access-style NICs.
  # vtnet0: WAN1
  network_device {
    bridge      = "vmbr0"
    mac_address = "02:00:00:00:01:00"
    model       = "virtio"
    vlan_id     = var.wan1_vlan_id
  }

  # vtnet1: WAN2. Leave the interface disabled in OPNsense until it is connected.
  network_device {
    bridge      = "vmbr0"
    mac_address = "02:00:00:00:01:01"
    model       = "virtio"
    vlan_id     = var.wan2_vlan_id
  }

  # vtnet2: infrastructure management
  network_device {
    bridge      = "vmbr0"
    mac_address = "02:00:00:00:00:10"
    model       = "virtio"
    vlan_id     = var.management_vlan_id
  }

  # vtnet3: trusted LAN
  network_device {
    bridge      = "vmbr0"
    mac_address = "02:00:00:00:00:20"
    model       = "virtio"
    vlan_id     = var.lan_vlan_id
  }

  on_boot         = true
  started         = true
  stop_on_destroy = true

  operating_system {
    type = "other"
  }
}
