#!/bin/bash
set -euo pipefail

VMID="${vm_id}"
IMG_URL="${img_url}"
IMG_SHA256="${img_sha256}"

echo "=== Downloading and decompressing installed OPNsense image ==="
wget -qO /var/tmp/opnsense.img.bz2 "$IMG_URL"
printf '%s  %s\n' "$IMG_SHA256" /var/tmp/opnsense.img.bz2 | sha256sum -c -
bunzip2 -c /var/tmp/opnsense.img.bz2 > /var/tmp/opnsense.img

echo "=== Importing installed disk ==="
qm importdisk "$VMID" /var/tmp/opnsense.img local-lvm --format raw
DISK=$(qm config "$VMID" | awk '/^unused0:/ {print $2}')

echo "=== Attaching installed disk $DISK ==="
qm set "$VMID" --virtio0 "$DISK"
qm set "$VMID" --boot order=virtio0
qm stop "$VMID" 2>/dev/null || true
rm -f /var/tmp/opnsense.img /var/tmp/opnsense.img.bz2
qm start "$VMID"

echo "=== Done ==="
