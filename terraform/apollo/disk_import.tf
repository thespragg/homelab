resource "null_resource" "opnsense_disk_import" {
  triggers = {
    image_url = var.opnsense_img_url
    vm_id     = proxmox_virtual_environment_vm.opnsense.vm_id
  }

  depends_on = [proxmox_virtual_environment_vm.opnsense]

  connection {
    type        = "ssh"
    host        = "apollo.internal.thespragg.dev"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/opnsense-provision.sh.tpl", {
      vm_id   = proxmox_virtual_environment_vm.opnsense.vm_id
      img_url = var.opnsense_img_url
    })
    destination = "/tmp/opnsense-provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/opnsense-provision.sh",
      "/tmp/opnsense-provision.sh",
      "rm -f /tmp/opnsense-provision.sh",
    ]
  }
}
