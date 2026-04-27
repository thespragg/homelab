# Homelab

## Prerequisites
- Ansible, Terraform installed
- SSH key access to hosts
- Vault password file at `~/.ansible/vault-password`

## First-time Proxmox setup (Apollo)

Run the Ansible proxmox playbook, then create the Terraform API token on Apollo:

```bash
pveum user add terraform@pve
pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve terraform --privsep 0
```

```bash
# Set vars
cp terraform/apollo/terraform.tfvars.example terraform/apollo/terraform.tfvars

cd terraform/apollo && terraform init && terraform apply
```

## Building a custom OPNsense image

```bash
bunzip2 -k OPNsense-*.img.bz2

qemu-system-x86_64 \
  -m 2048 \
  -drive file=OPNsense-*.img,format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::8080-:80,hostfwd=tcp::8443-:443 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

**Assign interfaces:**
```
VLANs: y
Parent: vtnet0 → tag 10, vtnet0 → tag 20, (blank)
WAN: vtnet0_vlan10  LAN: vtnet0_vlan20
```

**Set LAN IP:**
```
IPv4: 10.0.20.1/24, no gateway, DHCP 10.0.20.100–200
```

**Option 8 — Shell:**
```bash
passwd
viconfig   # add <ssh><enabled>enabled</enabled><group>admins</group></ssh> inside <system>
poweroff
```

```bash
cp OPNsense-*.img opnsense-custom.img && bzip2 opnsense-custom.img
# upload to R2, copy URL into terraform.tfvars → opnsense_img_url
```

## Running

```bash
ansible-playbook playbooks/proxmox.yml
ansible-playbook playbooks/osrs-clan-bot.yml
ansible-playbook playbooks/postgres.yml
ansible-playbook playbooks/monitoring.yml
ansible-playbook playbooks/caddy.yml
cd terraform/apollo && terraform apply
```

## OPNsense web UI

`http://10.0.20.1` — credentials: `root` / `opnsense`

## Bootstrap (fresh install)

Connect laptop to a VLAN 20 access port on the switch with a static IP (`10.0.20.x/24`, gateway `10.0.20.1`). Apollo is at `10.0.20.2` via L2 without OPNsense running.

```bash
ansible-playbook playbooks/proxmox.yml
cd terraform/apollo && terraform apply
```

## WAN Cutover

1. **Switch** — log in to Sodola (direct cable, static IP on 192.168.1.x):
   - ONT port: access, PVID 10
   - Apollo port: tagged VLAN 10
   - Disconnect Archer C6 WAN

2. **OPNsense** — Interfaces > Assignments: reassign WAN from `vtnet1` to `vtnet0_vlan10`, configure for ISP. Remove pre-cutover rules:
   - Firewall > Rules > WAN: remove `192.168.0.0/24 → This Firewall` and `192.168.0.0/24 → 10.0.20.0/24`
   - Firewall > Rules > LAN: remove `192.168.0.0/24` rule
   - Interfaces > WAN: re-enable "Block private networks"

3. **Terraform** — remove the temporary vtnet1 `network_device` block from `vms.tf`, run `terraform apply`

4. **Ansible** — swap the management IP/gateway in `inventory/host_vars/apollo/vars.yml` to the post-cutover values, run `ansible-playbook playbooks/proxmox.yml`

5. **DNS** — point devices to AdGuard on `10.0.20.x` (or set as upstream in OPNsense DHCP)

## Vault

```bash
ansible-vault edit inventory/host_vars/<host>/vault.yml
```
