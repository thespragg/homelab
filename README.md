# Homelab Ansible

## Prerequisites
- Ansible installed
- SSH key access to LXCs

## Running
Provision the bot LXC:
```bash
ansible-playbook playbooks/osrs-clan-bot.yml --ask-vault-pass
```

## Vault
Secrets are stored in `inventory/group_vars/all/vault.yml`.
To edit: `ansible-vault edit inventory/group_vars/all/vault.yml`
