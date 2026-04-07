resource "null_resource" "opnsense_disk_import" {
  triggers = {
    image_url = var.opnsense_img_url
    vm_id     = proxmox_virtual_environment_vm.opnsense.vm_id
  }

  depends_on = [
    proxmox_virtual_environment_vm.opnsense,
  ]

  connection {
    type        = "ssh"
    host        = "apollo.internal.thespragg.dev"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "wget -q -O /tmp/opnsense.img.bz2 '${var.opnsense_img_url}'",
      "bunzip2 -f /tmp/opnsense.img.bz2",
      "qm importdisk ${proxmox_virtual_environment_vm.opnsense.vm_id} /tmp/opnsense.img local-lvm --format raw",
      "qm set ${proxmox_virtual_environment_vm.opnsense.vm_id} --virtio0 local-lvm:vm-${proxmox_virtual_environment_vm.opnsense.vm_id}-disk-0",
      "qm set ${proxmox_virtual_environment_vm.opnsense.vm_id} --boot order=virtio0",
      "rm -f /tmp/opnsense.img",
      "qm start ${proxmox_virtual_environment_vm.opnsense.vm_id}",
    ]
  }
}
