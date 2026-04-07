resource "proxmox_download_file" "opnsense_img" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = "apollo"
  url                     = var.opnsense_img_url
  file_name               = "opnsense-vga-amd64.img"
  decompression_algorithm = "bz2"
  checksum_algorithm      = "sha256"
  checksum                = var.opnsense_img_checksum
  overwrite               = false
}
