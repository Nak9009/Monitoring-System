# Enterprise Monitoring Stack — Infrastructure as Code

Production-ready IaC for deploying **Zabbix 7.0 LTS + Grafana 11 + MySQL 8.0** monitoring infrastructure.

## Architecture

```
Zabbix Server 7.0 ──► MySQL 8.0 (Active-Standby Replication)
       │
       ├── Zabbix Frontend (Nginx + PHP)
       ├── Grafana 11 OSS (Dashboards)
       ├── Loki + Promtail (Logs)
       ├── Uptime Kuma (Synthetic Checks)
       └── Keepalived (HA Failover)
```

## Directory Structure

```
monitoring-stack/
├── docker-compose/          # Docker Compose deployment
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── configs/             # Service configurations
│   └── scripts/             # Helper scripts
├── ansible/                 # Ansible roles & playbooks
│   ├── ansible.cfg
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
│       ├── common/
│       ├── mysql/
│       ├── zabbix-server/
│       ├── zabbix-frontend/
│       ├── zabbix-agent/
│       ├── grafana/
│       ├── keepalived/
│       └── backup/
└── terraform/               # VM provisioning
    ├── modules/
    │   ├── proxmox-vm/
    │   └── vsphere-vm/
    ├── environments/
    │   └── production/
    └── cloud-init/
```

## Quick Start

### Option A: Docker Compose (fastest, for evaluation)
```bash
cd docker-compose
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

### Option B: Ansible (production, bare-metal/VM)
```bash
cd ansible
# Edit inventory/hosts.yml with your hosts
# Edit inventory/group_vars/all.yml with your settings
ansible-vault create inventory/group_vars/vault.yml
ansible-playbook playbooks/site.yml
```

### Option C: Terraform + Ansible (full IaC)
```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform plan && terraform apply
# Then run Ansible against provisioned VMs
```

## Ports Reference

| Port  | Service              |
|-------|---------------------|
| 443   | Zabbix Frontend     |
| 3000  | Grafana             |
| 3001  | Uptime Kuma         |
| 10051 | Zabbix Server       |
| 10050 | Zabbix Agent        |
| 3306  | MySQL               |
| 3100  | Loki                |
