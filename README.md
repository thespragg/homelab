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

## Building the installed OPNsense image

Build and configure the installed disk once, upload it privately to R2, and set
`opnsense_img_url` to a presigned download URL. The complete build procedure is
in `bootstrap/opnsense/README.md`.

Proxmox applies the VLAN tags before frames reach the VM. Do not create VLAN
subinterfaces in OPNsense. Terraform fixes the NIC order and MAC addresses as:

| OPNsense NIC | Purpose | VLAN | Address |
|---|---|---:|---|
| `vtnet0` | WAN1 | 901 | PPPoE/ISP configuration baked into image |
| `vtnet1` | WAN2 | 902 | Reserved until adoption |
| `vtnet2` | MGMT | 10 | `10.0.10.1/24` |
| `vtnet3` | DEVICES | 20 | `10.0.20.1/24` |
| `vtnet4` | IOT | 30 | `10.0.30.1/24` |
| `vtnet5` | HOMELAB | 40 | `10.0.40.1/24` |

**Set interface addresses:**
```
MGMT: 10.0.10.1/24, no gateway or DHCP
DEVICES: 10.0.20.1/24, DHCP 10.0.20.100–200
IOT: 10.0.30.1/24, DHCP 10.0.30.100–200
HOMELAB: 10.0.40.1/24, DHCP 10.0.40.100–200
```

The renderer also disables hardware offloading and adds the initial MGMT rule
allowing Apollo (`10.0.10.2`) to reach OPNsense. Ansible owns later changes.

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
| WAN1 | Access | 901 | None |
| Apollo | Trunk | 999 | 10, 20, 30, 40, 901, 902 |
| Access point | Trunk | 10 | 20, 30 and optionally 40 |
| Future WAN2 | Access | 902 | None; leave disconnected |

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
2. Build and upload the installed OPNsense image using the instructions above.
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
