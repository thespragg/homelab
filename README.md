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

## First-time Proxmox setup (Titan)

Titan is a second, separately-managed Proxmox host (not part of the `proxmox` Ansible group/role - only its LXCs are managed from this repo). To let Terraform provision containers on it, create an API token the same way as on Apollo, run on Titan itself:

```bash
pveum user add terraform@pve
pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve terraform --privsep 0
```

Then:

```bash
cp terraform/titan/terraform.tfvars.example terraform/titan/terraform.tfvars
# edit terraform.tfvars — add the token secret

cd terraform/titan && terraform init && terraform apply
```

This provisions the `paperless` LXC (10.0.40.9) using the `debian-12-standard` template already cached on Titan's `local` storage. Once it's up, run:

```bash
ansible-playbook playbooks/paperless.yml
```

**Assumptions baked into `terraform/titan/paperless.tf` that haven't been verified against a live apply yet** — check these before running `terraform apply`:
- Storage pool `ContainerStorage` is used for the container rootfs (confirmed present via `pvesm status`, but not exercised by Terraform yet).
- The container attaches to `vmbr0` (10.0.40.0/24, gateway 10.0.40.1) — this is Titan's primary LAN bridge, not the legacy `10.10.0.0/24` internal network (`vmbr1`) that postgres/grafana/osrs-clan-bot/immich (Titan's LXC copy) currently sit on. That network is currently unreachable and is being phased out; `postgres_host` in `inventory/group_vars/all/vars.yaml` assumes postgres will be reachable at `10.0.40.10` once migrated — update it once that actually happens.
- Caddy runs on Apollo at `10.0.40.4`, on the same subnet as `paperless` (10.0.40.9), so the reverse proxy entry in `inventory/host_vars/caddy/vars.yml` should work once `playbooks/caddy.yml` is re-run — it just needs postgres to be reachable first for paperless itself to come up.

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
| `vtnet6` | GUEST | 50 | `10.0.50.1/24` |

**Set interface addresses:**
```
MGMT: 10.0.10.1/24, no gateway or DHCP
DEVICES: 10.0.20.1/24, DHCP 10.0.20.100–200
IOT: 10.0.30.1/24, DHCP 10.0.30.100–200
HOMELAB: 10.0.40.1/24, DHCP 10.0.40.100–200
GUEST: 10.0.50.1/24, DHCP 10.0.50.100–200
```

The renderer also disables hardware offloading and adds the initial MGMT rule
allowing Apollo (`10.0.10.2`) to reach OPNsense. WAN1 is rendered as PPPoE on
`vtnet0`; its username and password come from `vault_opnsense_pppoe_username`
and `vault_opnsense_pppoe_password` in Apollo's encrypted vault. Ansible owns
later changes.

## Running

```bash
ansible-playbook playbooks/proxmox.yml
ansible-playbook playbooks/osrs-clan-bot.yml
ansible-playbook playbooks/postgres.yml
ansible-playbook playbooks/paperless.yml
ansible-playbook playbooks/monitoring.yml
ansible-playbook playbooks/caddy.yml
cd terraform/apollo && terraform apply
```

Terraform — provision LXCs on Titan:
```bash
cd terraform/titan && terraform apply
```

## OPNsense web UI

`http://10.0.10.1` from the management VLAN, or `http://10.0.20.1` from LAN.

## Network layout

| Switch port | Mode | Native/PVID | Tagged VLANs |
|---|---|---:|---|
| WAN1 | Access | 901 | None |
| Apollo | Trunk | 999 | 10, 20, 30, 40, 50, 901, 902 |
| Access point | Trunk | 10 | 20, 30, 50 and optionally 40 |
| Future WAN2 | Access | 902 | None; leave disconnected |

VLAN 999 is an unused native VLAN. It must not have an address or DHCP server.
Apollo's management address is `10.0.10.2`; OPNsense MGMT is `10.0.10.1`.

## Vault

```bash
ansible-vault edit inventory/host_vars/<host>/vault.yml
```

## UniFi Network automation

After the first UniFi Network onboarding, create an API key under **Settings >
Control Plane > Integrations**. Copy `inventory/host_vars/unifi/vault.yml.example`
to `vault.yml`, replace its values, and encrypt it with `ansible-vault encrypt`.

The `unifi_network` role creates the VLAN-only networks in UniFi and reconciles
one WPA2 PPSK SSID named `thespragg`. Its Devices, IoT, and Guest passwords map
clients to VLANs 20, 30, and 50 respectively. PPSK does not support WPA3 or the
6 GHz band. OPNsense provides routing, DHCP, and isolation; Guest can reach
AdGuard and the internet but is blocked from other private networks.
