# Production Deployment Manual: HA Monitoring Stack
## Zabbix 7.0 LTS + Grafana 11 + MySQL 8.0 Replication + Keepalived VIP

This document is the definitive operational guide for deploying the High-Availability (HA) monitoring infrastructure in a production environment. It covers system requirements, automated deployment (Terraform & Ansible), manual OS baselining, database replication, Keepalived VIP failover routing, and backup policies under strict resource constraints.

---

## 1. System Sizing & Network Architecture

### 1.1 Cluster Topology
The production cluster consists of two active-passive nodes sharing a Virtual IP (VIP) managed via Keepalived VRRP.

```
                    ┌──────────────────────────┐
                    │       Virtual IP (VIP)   │
                    │      10.0.100.100 (VRRP) │
                    └────────────┬─────────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 ▼ (Active)                      ▼ (Standby)
        ┌──────────────────┐            ┌──────────────────┐
        │   mon-primary    │            │   mon-standby    │
        │   10.0.100.10    │◄──────────►│   10.0.100.11    │
        │ (Server A - Master)  (Replicate) (Server B - Slave)  │
        └──────────────────┘            └──────────────────┘
```

### 1.2 Node Specifications
To operate reliably within a **4 GB RAM per node limit** without triggering Linux OOM (Out Of Memory) killers, resource configurations are tightly budgeted:

| Resource | Node Specification | Allocation Detail |
| :--- | :--- | :--- |
| **CPU** | 8 vCPUs | Standard workload processing |
| **RAM** | 4 GB | Strict memory budgets applied |
| **Disk** | 500 GB (SAS/SSD) | High-performance I/O for database transactions |
| **OS** | Ubuntu 24.04 LTS | Clean, minimal server installation |

### 1.3 Memory Allocation Budget (4 GB RAM Limit)
*   **MySQL InnoDB Buffer Pool**: `1 GB` (25% of total RAM)
*   **MySQL Max Connections**: `150` (prevents memory spikes under connection bursts)
*   **Zabbix Server Cache**: `128 MB`
*   **Zabbix History Cache**: `64 MB`
*   **Zabbix Value Cache**: `64 MB`
*   **Zabbix Trend Cache**: `32 MB`

---

## 2. Firewall Port Matrix

Configure your corporate switches, hypervisors, and local node firewalls to allow the following traffic:

| Source | Destination | Protocol / Port | Direction | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Users / Admins** | **VIP (10.0.100.100)** | `80, 443, 3000 / TCP` | Inbound | Web UI Access (Zabbix & Grafana) |
| **Monitored VMs** | **VIP (10.0.100.100)** | `10051 / TCP` | Inbound | Zabbix Active Agent checks |
| **VIP (10.0.100.100)** | **Monitored VMs** | `10050 / TCP` | Outbound | Zabbix Passive Agent checks |
| **mon-primary** | **mon-standby** | `3306 / TCP` | Inbound | MySQL Binlog Replication |
| **mon-primary** | **mon-standby** | `vrrp` | Bi-directional | Keepalived Heartbeats |

---

## 3. Automated Deployment (Terraform + Ansible)

### 3.1 Provisioning VMs (Terraform)
We support provisioning on both **VMware vSphere** and **Proxmox VE**.

1. Navigate to the Terraform production environment:
   ```bash
   cd terraform/environments/production
   ```
2. Open `terraform.tfvars` and set your credentials. Specify the target provider:
   ```hcl
   target_provider = "vsphere"  # or "proxmox"
   ```
3. Initialize and run:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```

### 3.2 Operating System & Stack Configuration (Ansible)
Once VMs are provisioned, Ansible automates the configuration of the network, firewalls, MySQL replication, Keepalived VIP, Zabbix Server, and Grafana:

1. Install Ansible on your control workstation:
   * **macOS**: `brew install ansible`
   * **Linux/Windows (pip)**: `pip3 install ansible`
2. Generate the inventory file:
   ```bash
   ../../scripts/generate-ansible-inventory.sh
   ```
3. Deploy the playbooks:
   ```bash
   cd ../../ansible
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml
   ```

---

## 4. Manual HA Installation Steps

If you are not using Ansible, follow these steps to build the cluster manually.

### 4.1 Base System Hardening (Both Nodes)
Run these commands on both `mon-primary` (`10.0.100.10`) and `mon-standby` (`10.0.100.11`):

```bash
# Set Hostnames
# On Primary:
sudo hostnamectl set-hostname mon-primary
# On Standby:
sudo hostnamectl set-hostname mon-standby

# Configure Network Time Protocol (NTP)
sudo timedatectl set-timezone Asia/Phnom_Penh
sudo systemctl enable --now systemd-timesyncd

# Configure UFW Firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp          # SSH
sudo ufw allow 80,443/tcp      # Web
sudo ufw allow 3000/tcp        # Grafana
sudo ufw allow 10050,10051/tcp # Zabbix Ports
sudo ufw allow 3306/tcp        # Database Replication
sudo ufw allow proto vrrp      # Keepalived heartbeat
sudo ufw --force enable
```

### 4.2 Database Replication (MySQL 8.0)
1. **Install MySQL Server** (Both Nodes):
   ```bash
   sudo apt install -y mysql-server
   ```

2. **Configure Primary Database** (`/etc/mysql/mysql.conf.d/zabbix.cnf` on `mon-primary`):
   ```ini
   [mysqld]
   bind-address = 0.0.0.0
   innodb_buffer_pool_size = 1G
   innodb_buffer_pool_instances = 1
   innodb_log_file_size = 256M
   innodb_log_buffer_size = 16M
   max_connections = 150
   server-id = 1
   log_bin = /var/log/mysql/mysql-bin.log
   binlog_format = ROW
   binlog_expire_logs_seconds = 259200
   log_bin_trust_function_creators = 1
   ```
   Restart service and configure replication credentials:
   ```bash
   sudo systemctl restart mysql
   sudo mysql -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   sudo mysql -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'VaultPasswordSecure123!';"
   sudo mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
   sudo mysql -e "CREATE USER 'zabbix'@'10.0.100.%' IDENTIFIED BY 'VaultPasswordSecure123!';"
   sudo mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'10.0.100.%';"
   sudo mysql -e "CREATE USER 'repl_user'@'%' IDENTIFIED BY 'ReplPasswordSecure123!';"
   sudo mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';"
   sudo mysql -e "FLUSH PRIVILEGES;"
   ```

3. **Configure Standby Database** (`/etc/mysql/mysql.conf.d/zabbix.cnf` on `mon-standby`):
   ```ini
   [mysqld]
   bind-address = 0.0.0.0
   innodb_buffer_pool_size = 1G
   innodb_buffer_pool_instances = 1
   innodb_log_file_size = 256M
   innodb_log_buffer_size = 16M
   max_connections = 150
   server-id = 2
   log_bin = /var/log/mysql/mysql-bin.log
   binlog_format = ROW
   binlog_expire_logs_seconds = 259200
   read_only = 1
   log_bin_trust_function_creators = 1
   ```
   Restart service and link replication:
   ```bash
   sudo systemctl restart mysql
   sudo mysql -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='10.0.100.10', SOURCE_USER='repl_user', SOURCE_PASSWORD='ReplPasswordSecure123!', GET_SOURCE_PUBLIC_KEY=1;"
   sudo mysql -e "START REPLICA;"
   ```
   Verify status: `sudo mysql -e "SHOW REPLICA STATUS\G"` (Verify `Replica_IO_Running: Yes` and `Replica_SQL_Running: Yes`).

### 4.3 Zabbix Server Clustering Configuration
1. **Install Zabbix repository and packages** (Both Nodes):
   ```bash
   wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
   sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
   sudo apt update && sudo apt install -y zabbix-server-mysql zabbix-sql-scripts
   ```

2. **Import Database Schema** (**On mon-primary ONLY**):
   ```bash
   zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u zabbix -p'VaultPasswordSecure123!' zabbix
   ```

3. **Configure Server configuration** (`/etc/zabbix/zabbix_server.conf`):
   *   **On Primary**:
       ```ini
       DBHost=10.0.100.10
       DBPassword=VaultPasswordSecure123!
       CacheSize=128M
       HistoryCacheSize=64M
       TrendCacheSize=32M
       ValueCacheSize=64M
       HANodeName=mon-primary
       NodeAddress=10.0.100.10:10051
       ```
   *   **On Standby**:
       ```ini
       DBHost=10.0.100.11
       DBPassword=VaultPasswordSecure123!
       CacheSize=128M
       HistoryCacheSize=64M
       TrendCacheSize=32M
       ValueCacheSize=64M
       HANodeName=mon-standby
       NodeAddress=10.0.100.11:10051
       ```
   Enable and start on both nodes:
   ```bash
   sudo systemctl enable --now zabbix-server
   ```

### 4.4 Keepalived VRRP Setup
1. **Install Keepalived** (Both Nodes):
   ```bash
   sudo apt install -y keepalived
   ```
2. **Create Health Check Script** (`/etc/keepalived/scripts/check_zabbix.sh` on both nodes):
   ```bash
   #!/bin/bash
   # Check if Zabbix Server and MySQL processes are healthy
   pgrep -f zabbix_server > /dev/null 2>&1
   ZABBIX_STATUS=$?
   nc -z 127.0.0.1 3306 > /dev/null 2>&1
   DB_STATUS=$?
   if [ $ZABBIX_STATUS -eq 0 ] && [ $DB_STATUS -eq 0 ]; then
       exit 0
   else
       exit 1
   fi
   ```
   Set permissions: `sudo chmod +x /etc/keepalived/scripts/check_zabbix.sh`
3. **Configure Server A (`keepalived.conf`)**:
   ```ini
   vrrp_script check_zabbix {
       script "/etc/keepalived/scripts/check_zabbix.sh"
       interval 3
       fall 2
       rise 2
   }
   vrrp_instance VI_1 {
       state BACKUP
       interface eth0
       virtual_router_id 51
       priority 101
       advert_int 1
       authentication {
           auth_type PASS
           auth_pass VrrpHAPassword123!
       }
       virtual_ipaddress {
           10.0.100.100/24 dev eth0
       }
       track_script {
           check_zabbix
       }
   }
   ```
4. **Configure Server B (`keepalived.conf`)**:
   Keep the configuration identical, but change `priority` to `100`.
5. **Start Keepalived** (Both Nodes):
   ```bash
   sudo systemctl enable --now keepalived
   ```

---

## 5. Post-Deployment Verification & Failover Testing

### 5.1 Verification Commands
Verify the HA status of Zabbix Server:
```bash
zabbix_server -R ha_status
```
*Expected Output:*
```text
Failover delay: 60 seconds
Active: mon-primary [10.0.100.10:10051] (status: active, heartbeat: 2s ago)
Standby: mon-standby [10.0.100.11:10051] (status: standby, heartbeat: 4s ago)
```

### 5.2 Performing a Failover Test
1. Connect via SSH to `mon-primary`.
2. Stop Zabbix Server:
   ```bash
   sudo systemctl stop zabbix-server
   ```
3. Observe `mon-standby`. The Virtual IP (`10.0.100.100`) will automatically switch to `mon-standby` within 3 seconds, and the standby Zabbix Server node will transition to `active`.
4. Restore `mon-primary`:
   ```bash
   sudo systemctl start zabbix-server
   ```
   `mon-primary` will rejoin as a `standby` node, waiting to take over in the next failure event.

---

## 6. Automating Target VM Deployment (40+ Hosts)

To deploy monitoring across a large infrastructure:

1. **Deploy Agents**: List all your VM IPs in `ansible/inventory/hosts.yml` under `[monitored_hosts]` and run:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/deploy_agents.yml
   ```
2. **Auto-Enrollment**: In Zabbix Web UI, configure **Active Agent Auto-Registration**:
   * Navigate to **Alerts** -> **Actions** -> **Autoregistration actions**.
   * Create an action to match Host Metadata `LinuxServer` or `WindowsServer`.
   * Add operations: **Add host**, **Add to host group** (e.g., `Virtual Machines`), and **Link to templates** (e.g., `Linux by Zabbix agent`).
   * Any new VM deployed with Zabbix Agent pointing to `10.0.100.100` will be discovered and monitored automatically!

---

## 7. Production Backups

The monitoring stack includes an automated backup script at `docker-compose/scripts/backup.sh` (or `ansible/roles/backup/files/backup.sh`).

### 7.1 Backup Schedule
Configure a nightly cron job on the active database node to dump configuration schemas and data:

```bash
# Edit crontab
sudo crontab -e

# Add nightly backup at 02:00 AM
0 2 * * * /opt/monitoring/scripts/backup.sh > /var/log/monitoring-backup.log 2>&1
```

### 7.2 Stored Data Retention
By default, backups are archived in `/opt/backups/monitoring` and retention is managed according to the `.env` variable `BACKUP_RETENTION_DAYS=30`. High-activity historical trend data inside the DB is automatically cleaned by Zabbix's built-in **Housekeeper** daemon.
