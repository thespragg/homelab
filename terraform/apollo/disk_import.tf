resource "null_resource" "opnsense_disk_import" {
  triggers = {
    image_checksum = var.opnsense_img_checksum
    vm_id          = proxmox_virtual_environment_vm.opnsense.id
  }

  depends_on = [
    proxmox_virtual_environment_vm.opnsense,
    proxmox_download_file.opnsense_img,
  ]

  connection {
    type        = "ssh"
    host        = "apollo.internal.thespragg.dev"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "dd if=/var/lib/vz/template/iso/opnsense-vga-amd64.img of=/dev/pve/vm-100-disk-0 bs=8M status=progress",
      "qm start 100",
    ]
  }
}
