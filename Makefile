.DEFAULT_GOAL := all

.PHONY: all apollo apollo-ansible opnsense-bootstrap-config opnsense-config-disk titan titan-ansible plan check help

all: apollo titan ## Deploy everything

apollo: ## Full Apollo deploy (Terraform + Ansible)
	terraform -chdir=terraform/apollo init -input=false
	terraform -chdir=terraform/apollo apply -auto-approve
	ansible-playbook playbooks/apollo.yml

apollo-ansible: ## Ansible only for Apollo
	ansible-playbook playbooks/apollo.yml

opnsense-bootstrap-config: ## Render config.xml for the stock OPNsense importer
	python3 scripts/render-opnsense-bootstrap.py \
		bootstrap/opnsense/config.xml.sample build/opnsense/conf/config.xml \
		--ssh-public-key "$${SSH_PUBLIC_KEY_PATH:-$$HOME/.ssh/id_ed25519.pub}"

opnsense-config-disk: opnsense-bootstrap-config ## Build the FAT OPNsense importer disk (run on Linux)
	sh scripts/create-opnsense-config-disk.sh

titan: titan-ansible ## Full Titan deploy (Ansible only until Terraform is added)

titan-ansible: ## Ansible only for Titan
	ansible-playbook playbooks/titan.yml

plan: ## Terraform plan for Apollo (no apply)
	terraform -chdir=terraform/apollo init -input=false
	terraform -chdir=terraform/apollo plan

check: ## Ansible dry-run across all playbooks
	ansible-playbook site.yml --check

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
