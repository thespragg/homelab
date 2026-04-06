# Homelab Ansible

## Prerequisites
- Ansible installed
- SSH key access to LXCs
- Vault password file at `~/.ansible/vault-password`

## Running

Provision everything:
```bash
ansible-playbook site.yml
```

Or provision a specific service:
```bash
ansible-playbook playbooks/osrs-clan-bot.yml
ansible-playbook playbooks/postgres.yml
ansible-playbook playbooks/monitoring.yml
ansible-playbook playbooks/caddy.yml
```

## WAN Cutover (Apollo)

When ready to cut over from the Archer C6 to OPNsense as the main router:

1. **Switch** — log in to Sodola (192.168.1.x via direct cable + static IP):
   - Set ONT port to access port, PVID 10
   - Add tagged VLAN 10 to Apollo's trunk port
   - Disconnect Archer C6 WAN port

2. **OPNsense** — swap the WAN interface from the temporary bridge (192.168.0.x) to the VLAN 10 interface and configure it for your ISP (DHCP or PPPoE)

3. **Proxmox** — update `inventory/host_vars/apollo/vars.yml`:
   - Uncomment the post-cutover `proxmox_management_ip` and `proxmox_management_gateway` lines
   - Comment out the pre-cutover values
   - Re-run `ansible-playbook playbooks/proxmox.yml`

4. **DNS** — point devices to AdGuard on 10.0.20.x (or set it as upstream in OPNsense DHCP)

## Vault
Secrets are stored in per-host vault files under `inventory/host_vars/` and globally in `inventory/group_vars/all/vault.yml`.

To edit a vault file:
```bash
ansible-vault edit inventory/host_vars/<host>/vault.yml
```
