#!/bin/bash
set -euo pipefail

VMID="${vm_id}"
IMG_URL="${img_url}"

echo "=== Downloading and decompressing OPNsense image ==="
wget -qO- "$IMG_URL" | bunzip2 -c > /var/tmp/opnsense.img

echo "=== Importing disk ==="
qm importdisk "$VMID" /var/tmp/opnsense.img local-lvm --format raw
rm -f /var/tmp/opnsense.img

echo "=== Finding imported disk ==="
DISK=$(qm config "$VMID" | grep '^unused0:' | awk '{print $2}')

echo "=== Attaching disk $DISK ==="
qm set "$VMID" --virtio0 "$DISK"
qm set "$VMID" --boot order=virtio0
qm start "$VMID"

echo "=== Done ==="
