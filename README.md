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
VLANs: n
WAN: vtnet0
LAN: vtnet3
OPT1: vtnet1, named WAN2 and left disabled
OPT2: vtnet2, named MGMT
```

Proxmox applies the VLAN tags before frames reach the VM. Do not create VLAN
subinterfaces in OPNsense. Terraform fixes the NIC order and MAC addresses as:

| OPNsense NIC | Purpose | VLAN | Address |
|---|---|---:|---|
| `vtnet0` | WAN1 | 100 | ISP configuration |
| `vtnet1` | WAN2 | 101 | Disabled until connected |
| `vtnet2` | MGMT | 10 | `10.0.10.1/24` |
| `vtnet3` | LAN | 20 | `10.0.20.1/24` |

**Set interface addresses:**
```
MGMT: 10.0.10.1/24, no gateway or DHCP
LAN: 10.0.20.1/24, no gateway, DHCP 10.0.20.100–200
```

Before exporting the image, add a rule on MGMT allowing source `10.0.10.2` to
"This Firewall" on the API port. This bootstrap rule is required because
OPNsense does not provide a supported API for initial interface assignment or
for creating a rule before its API is reachable. The Ansible role owns the
subsequent LAN-to-Proxmox management rules.

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

`http://10.0.10.1` from the management VLAN, or `http://10.0.20.1` from LAN.

## Bootstrap (fresh install)

Configure the switch before moving Apollo's management address:

| Switch port | Mode | Native/PVID | Tagged VLANs |
|---|---|---:|---|
| WAN1 | Access | 100 | None |
| Apollo | Trunk | 999 | 10, 20, 100, 101 |
| Access point | Trunk | 10 | 20 and any SSID VLANs |
| Future WAN2 | Access | 101 | None; leave disconnected |

VLAN 999 is an unused native VLAN. It must not have an address or DHCP server.
Connect a laptop to a VLAN 10 access port with a temporary `10.0.10.x/24`
address for the management cutover. Apollo will move to `10.0.10.2` and
OPNsense MGMT is `10.0.10.1`.

```bash
ansible-playbook playbooks/proxmox.yml
cd terraform/apollo && terraform apply
```

## Network Cutover

1. Configure the Sodola ports using the table above. Do not connect WAN2.
2. Rebuild/upload the OPNsense image with the four interface assignments above.
3. Run `ansible-playbook playbooks/proxmox.yml` from the workstation while you
   have local Proxmox console access. The SSH session will drop when management
   moves to VLAN 10; use the console if the network reload needs intervention.
4. Verify `https://10.0.10.2:8006` from the temporary VLAN 10 laptop connection.
5. Run `terraform -chdir=terraform/apollo apply`, then `make apollo-ansible`.
6. Move the laptop back to trusted LAN/DHCP and verify that
   `https://10.0.10.2:8006` routes through OPNsense.
7. Connect WAN1 and configure its ISP settings. Keep WAN2 disabled until its
   switch port and upstream circuit are available.

## Vault

```bash
ansible-vault edit inventory/host_vars/<host>/vault.yml
```
