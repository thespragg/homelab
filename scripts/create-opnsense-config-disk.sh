#!/bin/sh
set -eu

CONFIG=${1:-build/opnsense/conf/config.xml}
OUTPUT=${2:-build/opnsense/opnsense-config.img}

command -v mkfs.vfat >/dev/null || {
  echo "mkfs.vfat is required (install dosfstools)" >&2
  exit 1
}
command -v mcopy >/dev/null || {
  echo "mcopy is required (install mtools)" >&2
  exit 1
}

test -f "$CONFIG"
mkdir -p "$(dirname "$OUTPUT")"
truncate -s 8M "$OUTPUT"
mkfs.vfat -n OPNCONFIG "$OUTPUT" >/dev/null
mmd -i "$OUTPUT" ::conf
mcopy -i "$OUTPUT" "$CONFIG" ::conf/config.xml
echo "Created $OUTPUT"
