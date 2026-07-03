# Build the installed OPNsense image

This is a one-time local build. Terraform later downloads the resulting
installed disk from R2, imports it into Proxmox, and boots it directly.

## Prepare

Download the official OPNsense **serial** image and verify it using the release
checksum/signature. Then create a separate installation target:

```bash
bunzip2 -k OPNsense-*-serial-amd64.img.bz2
mv OPNsense-*-serial-amd64.img opnsense-installer.img
qemu-img create -f raw opnsense-apollo.img 16G
make opnsense-bootstrap-config
```

The generated `build/opnsense/conf/config.xml` supplies the seven interface
assignments, WAN1 PPPoE configuration, addresses, initial firewall access, root
SSH key, and offloading settings. PPPoE credentials are read from Apollo's
encrypted Ansible vault. QEMU exposes that directory to the importer as a
virtual FAT disk.

## Install

```bash
qemu-system-x86_64 \
  -m 4096 \
  -drive file=opnsense-installer.img,format=raw,if=virtio,readonly=on \
  -drive file=opnsense-apollo.img,format=raw,if=virtio \
  -drive file=fat:rw:build/opnsense,format=raw,if=virtio \
  -netdev user,id=net0,net=172.16.1.0/24 \
  -device virtio-net-pci,netdev=net0,mac=02:00:00:00:01:00 \
  -netdev user,id=net1,net=172.16.2.0/24 \
  -device virtio-net-pci,netdev=net1,mac=02:00:00:00:01:01 \
  -netdev user,id=net2,net=10.0.10.0/24,host=10.0.10.2,hostfwd=tcp::8080-10.0.10.1:80,hostfwd=tcp::2222-10.0.10.1:22 \
  -device virtio-net-pci,netdev=net2,mac=02:00:00:00:00:10 \
  -netdev user,id=net3,net=10.0.20.0/24,host=10.0.20.254 \
  -device virtio-net-pci,netdev=net3,mac=02:00:00:00:00:20 \
  -netdev user,id=net4,net=10.0.30.0/24,host=10.0.30.254 \
  -device virtio-net-pci,netdev=net4,mac=02:00:00:00:00:30 \
  -netdev user,id=net5,net=10.0.40.0/24,host=10.0.40.254 \
  -device virtio-net-pci,netdev=net5,mac=02:00:00:00:00:40 \
  -netdev user,id=net6,net=10.0.50.0/24,host=10.0.50.254 \
  -device virtio-net-pci,netdev=net6,mac=02:00:00:00:00:50 \
  -nographic
```

At the importer prompt, press a key and select the third disk (`vtbd2`) containing
`/conf/config.xml`. Log in as `installer` / `opnsense`, install onto the second
disk (`vtbd1`), and use UFS or a single-disk ZFS stripe. Do not install onto
`vtbd0`, which is the installer media.

When installation completes, power off instead of starting another installation.

## Configure and verify

Boot only the installed disk, retaining the seven NICs from the previous command:

```bash
qemu-system-x86_64 \
  -m 4096 \
  -drive file=opnsense-apollo.img,format=raw,if=virtio \
  -netdev user,id=net0,net=172.16.1.0/24 \
  -device virtio-net-pci,netdev=net0,mac=02:00:00:00:01:00 \
  -netdev user,id=net1,net=172.16.2.0/24 \
  -device virtio-net-pci,netdev=net1,mac=02:00:00:00:01:01 \
  -netdev user,id=net2,net=10.0.10.0/24,host=10.0.10.2,hostfwd=tcp::8080-10.0.10.1:80,hostfwd=tcp::2222-10.0.10.1:22 \
  -device virtio-net-pci,netdev=net2,mac=02:00:00:00:00:10 \
  -netdev user,id=net3,net=10.0.20.0/24,host=10.0.20.254 \
  -device virtio-net-pci,netdev=net3,mac=02:00:00:00:00:20 \
  -netdev user,id=net4,net=10.0.30.0/24,host=10.0.30.254 \
  -device virtio-net-pci,netdev=net4,mac=02:00:00:00:00:30 \
  -netdev user,id=net5,net=10.0.40.0/24,host=10.0.40.254 \
  -device virtio-net-pci,netdev=net5,mac=02:00:00:00:00:40 \
  -netdev user,id=net6,net=10.0.50.0/24,host=10.0.50.254 \
  -device virtio-net-pci,netdev=net6,mac=02:00:00:00:00:50 \
  -nographic
```

Open `http://127.0.0.1:8080`, log in as `root` / `opnsense`, and:

1. Change the root password.
2. Create an API key under **System > Access > Users > root**.
3. Put the key and secret in `inventory/host_vars/apollo/vault.yml` as
   `vault_opnsense_api_key` and `vault_opnsense_api_secret`.
4. Confirm interfaces are `vtnet0` through `vtnet6` in the documented order.
5. Confirm WAN1 uses PPPoE over `vtnet0` and has internet connectivity.
6. Confirm checksum, TSO and LRO offloading are disabled.
7. Shut down cleanly from the console.

## Compress and upload

```bash
bzip2 -9 -k opnsense-apollo.img
shasum -a 256 opnsense-apollo.img.bz2

/usr/local/bin/aws s3 cp opnsense-apollo.img.bz2 \
  s3://opnsense/opnsense.img.bz2 \
  --profile r2 \
  --endpoint-url https://c1023396fac1dd631cd7845a56aa1730.r2.cloudflarestorage.com
```

The AWS CLI automatically uses multipart upload for images over Wrangler's
300 MiB limit. This overwrites the existing object, so the current R2 URL remains
unchanged. Put the new `shasum` value in `terraform/apollo/terraform.tfvars` as
`opnsense_img_sha256`.
