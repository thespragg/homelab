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

## Vault
Secrets are stored in per-host vault files under `inventory/host_vars/` and globally in `inventory/group_vars/all/vault.yml`.

To edit a vault file:
```bash
ansible-vault edit inventory/host_vars/<host>/vault.yml
```
