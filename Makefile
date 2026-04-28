.DEFAULT_GOAL := all

.PHONY: all apollo apollo-ansible titan titan-ansible plan check help

all: apollo titan ## Deploy everything

apollo: ## Full Apollo deploy (Terraform + Ansible)
	terraform -chdir=terraform/apollo init -input=false
	terraform -chdir=terraform/apollo apply -auto-approve
	ansible-playbook playbooks/apollo.yml

apollo-ansible: ## Ansible only for Apollo
	ansible-playbook playbooks/apollo.yml

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
