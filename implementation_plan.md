# Implementation Plan — Enterprise Monitoring Stack Deployment & Provisioning

This plan outlines the implementation of Ansible roles and Terraform configurations to deploy the Zabbix 7.0, Grafana, and PostgreSQL monitoring stack.

## Proposed Changes

We will create a structured Ansible configuration and a multi-provider Terraform configuration under `/Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/`.

### 1. Ansible Configurations
We will create the Ansible directory structure to manage the configuration and deployment of Zabbix agents, servers, databases, Grafana, Keepalived HA, and automated backups.

- [NEW] [ansible.cfg](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/ansible.cfg)
- [NEW] [inventory/hosts.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/inventory/hosts.yml)
- [NEW] [inventory/group_vars/all.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/inventory/group_vars/all.yml)
- [NEW] [playbooks/site.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/playbooks/site.yml)
- [NEW] [playbooks/deploy_monitoring_server.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/playbooks/deploy_monitoring_server.yml)
- [NEW] [playbooks/deploy_agents.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/playbooks/deploy_agents.yml)
- [NEW] [playbooks/setup_ha.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/ansible/playbooks/setup_ha.yml)
- [NEW] Roles: `common`, `postgresql`, `zabbix-server`, `zabbix-frontend`, `zabbix-agent`, `grafana`, `keepalived`, `backup`.

### 2. Terraform Configurations
We will create the Terraform directory structure to provision monitoring VMs on Proxmox or vSphere.

- [NEW] [main.tf](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/main.tf)
- [NEW] [variables.tf](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/variables.tf)
- [NEW] [outputs.tf](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/outputs.tf)
- [NEW] [terraform.tfvars.example](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/terraform.tfvars.example)
- [NEW] [versions.tf](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/versions.tf)
- [NEW] [modules/proxmox-vm](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/modules/proxmox-vm) (main.tf, variables.tf, outputs.tf)
- [NEW] [modules/vsphere-vm](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/modules/vsphere-vm) (main.tf, variables.tf, outputs.tf)
- [NEW] [cloud-init/monitoring-server.yml](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/cloud-init/monitoring-server.yml)
- [NEW] [scripts/generate-ansible-inventory.sh](file:///Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/terraform/scripts/generate-ansible-inventory.sh)

---

## Verification Plan

### Dry-run / Validation
- Run `ansible-playbook --syntax-check` on playbooks.
- Run `terraform validate` and `terraform fmt -check` on Terraform configurations.
