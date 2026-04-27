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

  # trunk - vtnet0, passes tagged frames (VLAN 10 WAN, VLAN 20 LAN) at cutover
  # OPNsense creates vlan subinterfaces internally (vtnet0_vlan10, vtnet0_vlan20)
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # WAN - vtnet1, untagged, temporary internet via existing router during build phase
  # Remove at cutover
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  on_boot = true
  started         = true
  stop_on_destroy = true

  operating_system {
    type = "other"
  }
}
