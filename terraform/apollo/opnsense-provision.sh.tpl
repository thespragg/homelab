#!/bin/bash
set -euo pipefail

VMID="${vm_id}"
IMG_URL="${img_url}"

echo "=== Downloading and decompressing OPNsense image ==="
wget -qO- "$IMG_URL" | bunzip2 -c > /var/tmp/opnsense-nano.img

echo "=== Importing disk ==="
qm importdisk "$VMID" /var/tmp/opnsense-nano.img local-lvm --format raw
rm -f /var/tmp/opnsense-nano.img

echo "=== Attaching disk and starting VM ==="
qm set "$VMID" --virtio0 "local-lvm:vm-$VMID-disk-0"
qm set "$VMID" --boot order=virtio0
qm start "$VMID"

echo "Done."
