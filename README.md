# Homelab

## Prerequisites
- Ansible installed
- Terraform installed
- SSH key access to hosts
- Vault password file at `~/.ansible/vault-password`

## First-time Proxmox setup (Apollo)

After running the Ansible proxmox playbook, create the Terraform API token on apollo:

```bash
pveum user add terraform@pve
pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve terraform --privsep 0
```

Then set up the Terraform credentials:

```bash
cp terraform/apollo/terraform.tfvars.example terraform/apollo/terraform.tfvars
# edit terraform.tfvars — add the token secret, and the OPNsense VGA image URL + checksum
# from https://opnsense.org/download/ (VGA image, amd64)
```

Then initialise and apply:

```bash
cd terraform/apollo && terraform init && terraform apply
```

## Building a custom OPNsense image

Terraform expects a pre-configured OPNsense image hosted at a URL. To build one:

**1. Download and extract the base nano image**

Get the nano amd64 image from https://opnsense.org/download/ and extract it:

```bash
bunzip2 -k OPNsense-*.img.bz2
```

**2. Boot in QEMU**

```bash
brew install qemu

qemu-system-x86_64 \
  -m 2048 \
  -drive file=OPNsense-*.img,format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::8080-:80,hostfwd=tcp::8443-:443 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

**3. Assign interfaces** (option `1`)

```
Do you want to set up VLANs now? y

Parent interface: vtnet0  →  VLAN tag: 10
Parent interface: vtnet0  →  VLAN tag: 20
Parent interface: (blank)

WAN interface: vtnet0_vlan10
LAN interface: vtnet0_vlan20
Optional:      (blank)
Proceed?       y
```

**4. Set LAN IP address** (option `2`, select LAN)

```
IPv4 via DHCP:   n
IPv4 address:    10.0.20.1
Subnet bits:     24
Upstream GW:     (blank)
IPv6 via DHCP6:  n
IPv6 address:    (blank)
Enable DHCP:     y
DHCP start:      10.0.20.100
DHCP end:        10.0.20.200
Revert to HTTP:  n
```

**5. Set root password and enable SSH** (option `8` — Shell)

```bash
passwd
viconfig   # add <ssh><enabled>enabled</enabled><group>admins</group></ssh> inside <system>
exit
```

**6. Power off**

```bash
poweroff
```

**7. Recompress and upload**

```bash
cp OPNsense-*.img opnsense-custom.img
bzip2 opnsense-custom.img
# upload opnsense-custom.img.bz2 to Cloudflare R2 (or equivalent)
# copy the public URL into terraform/apollo/terraform.tfvars → opnsense_img_url
```

## Accessing OPNsense web UI

Apollo has a VLAN 20 interface at `10.0.20.2`, so you can tunnel through it rather than needing a device physically on VLAN 20:

```bash
ssh -L 8080:10.0.20.1:80 root@192.168.0.94 -N
```

Then browse to `http://localhost:8080`. Default credentials: `root` / `opnsense`.

## Running

Ansible — provision everything:
```bash
ansible-playbook site.yml
```

Or a specific service:
```bash
ansible-playbook playbooks/proxmox.yml
ansible-playbook playbooks/osrs-clan-bot.yml
ansible-playbook playbooks/postgres.yml
ansible-playbook playbooks/monitoring.yml
ansible-playbook playbooks/caddy.yml
```

Terraform — provision VMs and LXCs on Apollo:
```bash
cd terraform/apollo && terraform apply
```

## WAN Cutover (Apollo)

When ready to cut over from the Archer C6 to OPNsense as the main router:

1. **Switch** — log in to Sodola (192.168.1.x via direct cable + static IP):
   - Set ONT port to access port, PVID 10
   - Add tagged VLAN 10 to Apollo's trunk port
   - Disconnect Archer C6 WAN port

2. **OPNsense** — swap the WAN interface from the temporary untagged bridge to the VLAN 10 interface and configure for your ISP (DHCP or PPPoE)

3. **Terraform** — update `terraform/apollo/vms.tf`, OPNsense WAN network device:
   - Add `vlan_id = 10` to the first `network_device` block
   - Run `terraform apply`

4. **Ansible** — update `inventory/host_vars/apollo/vars.yml`:
   - Uncomment the post-cutover `proxmox_management_ip` and `proxmox_management_gateway` lines
   - Comment out the pre-cutover values
   - Run `ansible-playbook playbooks/proxmox.yml`

5. **DNS** — point devices to AdGuard on 10.0.20.x (or set it as upstream in OPNsense DHCP)

## Vault
Secrets are stored in per-host vault files under `inventory/host_vars/` and globally in `inventory/group_vars/all/vault.yml`.

To edit a vault file:
```bash
ansible-vault edit inventory/host_vars/<host>/vault.yml
```
