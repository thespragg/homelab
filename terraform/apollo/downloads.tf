# Download is handled directly on the Proxmox host in disk_import.tf for OPNsense
# (bz2 decompression via the provider is unreliable for that case).
# LXC templates use tar.zst which the provider handles correctly.

resource "proxmox_download_file" "debian_lxc_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "apollo"
  url          = var.debian_lxc_template_url
}
