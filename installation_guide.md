# Comprehensive Installation & Configuration Guide: HA Monitoring Stack

This document serves as the complete operational guide for deploying the Zabbix 7.0 + Grafana 11 + MySQL monitoring stack on-premises using VMware vSphere. It details both automated (Terraform + Ansible) and manual configurations for setting up a High-Availability (HA) cluster under a strict **4 GB RAM per node** memory limit.

---

## 1. System Sizing & Architecture

### Node Specifications
- **VM A (Primary - `mon-primary`)**: 8 vCPUs, 4 GB RAM, 500 GB Disk, Ubuntu 24.04 LTS.
- **VM B (Standby - `mon-standby`)**: 8 vCPUs, 4 GB RAM, 500 GB Disk, Ubuntu 24.04 LTS.
- **Virtual IP (VIP - `mon-vip`)**: `10.0.100.100` managed by Keepalived.

### Sizing and Memory Budget (4 GB RAM Limit)
To prevent Linux out-of-memory (OOM) killer occurrences, database and server caches are restricted as follows:
- **MySQL InnoDB Buffer Pool Size**: `1 GB` (25% of RAM)
- **MySQL Max Connections**: `150` (safe for 4 GB RAM VM node limits)
- **MySQL InnoDB Log File Size**: `256 MB`
- **MySQL InnoDB Log Buffer Size**: `16 MB`
- **Zabbix server cache**: `128 MB`
- **Zabbix history cache**: `64 MB`
- **Zabbix value cache**: `64 MB`
- **Zabbix trend cache**: `32 MB`

---

## 2. Option A: Automated Deployment (Recommended)

The project includes pre-configured Terraform and Ansible configurations to bootstrap the servers automatically.

1. **Configure vSphere Credentials**:
   Edit `terraform/environments/production/terraform.tfvars` with your vCenter details and set `target_provider = "vsphere"`.

2. **Initialize and Provision VMs**:
   ```bash
   cd terraform/environments/production
   terraform init
   terraform apply -auto-approve
   ```

3. **Generate Ansible Inventory**:
   Extract VM IP addresses from the Terraform state:
   ```bash
   ../../scripts/generate-ansible-inventory.sh
   ```

4. **Deploy Stack via Ansible**:
   Run the Ansible playbook to automatically configure both nodes:
   ```bash
   cd ../../ansible
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml
   ```

---

## 3. Option B: Manual Step-by-Step HA Setup

Follow these manual configuration steps if you prefer to build the stack directly inside the guest OS.

### 3.1 Network & OS Baselining (Both Nodes)

1. **Set hostnames**:
   - **On Server A (`10.0.100.10`)**:
     ```bash
     sudo hostnamectl set-hostname mon-primary
     ```
   - **On Server B (`10.0.100.11`)**:
     ```bash
     sudo hostnamectl set-hostname mon-standby
     ```

2. **Update Hosts File** (Append to `/etc/hosts` on both nodes):
   ```text
   10.0.100.10 mon-primary
   10.0.100.11 mon-standby
   10.0.100.100 mon-vip
   ```

3. **Harden Firewalls (UFW)** (Execute on both nodes):
   ```bash
   sudo apt update && sudo apt install -y ufw systemd-timesyncd fping net-tools
   sudo timedatectl set-timezone Asia/Bangkok
   
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp      # SSH
   sudo ufw allow 10051/tcp   # Zabbix Server
   sudo ufw allow 10050/tcp   # Zabbix Agent
   sudo ufw allow 80,443/tcp  # Web UI
   sudo ufw allow 3000/tcp    # Grafana Web
   sudo ufw allow 3306/tcp    # MySQL Replication
   sudo ufw allow proto vrrp  # Keepalived Heartbeat
   sudo ufw --force enable
   ```

---

### 3.2 MySQL 8.0 HA Setup

1. **Install Packages** (Run on both nodes):
   ```bash
   sudo apt update
   sudo apt install -y mysql-server python3-pymysql
   ```

2. **Configure Server A (Primary DB)**:
   - Create a custom tuned file `/etc/mysql/mysql.conf.d/zabbix.cnf` (Tuned for 4 GB RAM):
     ```ini
     [mysqld]
     port = 3306
     bind-address = 0.0.0.0
     innodb_buffer_pool_size = 1G
     innodb_buffer_pool_instances = 1
     innodb_log_file_size = 256M
     innodb_log_buffer_size = 16M
     max_connections = 150
     innodb_flush_log_at_trx_commit = 2
     innodb_flush_method = O_DIRECT
     server-id = 1
     log_bin = /var/log/mysql/mysql-bin.log
     binlog_format = ROW
     binlog_expire_logs_seconds = 259200
     log_bin_trust_function_creators = 1
     skip-name-resolve
     character-set-server = utf8mb4
     collation-server = utf8mb4_unicode_ci
     ```
   - Restart MySQL and create the database and users:
     ```bash
     sudo systemctl restart mysql
     sudo mysql -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
     sudo mysql -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'VaultPasswordPlaceholder123!';"
     sudo mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
     sudo mysql -e "CREATE USER 'zabbix'@'10.0.100.%' IDENTIFIED BY 'VaultPasswordPlaceholder123!';"
     sudo mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'10.0.100.%';"
     sudo mysql -e "CREATE USER 'repl_user'@'%' IDENTIFIED BY 'YourReplPassword123!';"
     sudo mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';"
     sudo mysql -e "FLUSH PRIVILEGES;"
     ```

3. **Configure Server B (Replica DB)**:
   - Create custom tuned file `/etc/mysql/mysql.conf.d/zabbix.cnf` on Server B (Tuned for 4 GB RAM, Read-Only):
     ```ini
     [mysqld]
     port = 3306
     bind-address = 0.0.0.0
     innodb_buffer_pool_size = 1G
     innodb_buffer_pool_instances = 1
     innodb_log_file_size = 256M
     innodb_log_buffer_size = 16M
     max_connections = 150
     innodb_flush_log_at_trx_commit = 2
     innodb_flush_method = O_DIRECT
     server-id = 2
     log_bin = /var/log/mysql/mysql-bin.log
     binlog_format = ROW
     binlog_expire_logs_seconds = 259200
     relay-log = /var/log/mysql/mysql-relay-bin.log
     read_only = 1
     log_bin_trust_function_creators = 1
     skip-name-resolve
     character-set-server = utf8mb4
     collation-server = utf8mb4_unicode_ci
     ```
   - Restart MySQL:
     ```bash
     sudo systemctl restart mysql
     ```
   - Start replication from Server A (Primary) on Server B:
     ```bash
     sudo mysql -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='10.0.100.10', SOURCE_USER='repl_user', SOURCE_PASSWORD='YourReplPassword123!', GET_SOURCE_PUBLIC_KEY=1;"
     sudo mysql -e "START REPLICA;"
     ```
   - Verify replication on Server B:
     ```bash
     sudo mysql -e "SHOW REPLICA STATUS\G"
     ```
     *(Ensure both `Replica_IO_Running` and `Replica_SQL_Running` are `Yes`)*

---

### 3.3 Zabbix 7.0 LTS Server Setup

1. **Install Zabbix Repo & Server Packages** (Both nodes):
   ```bash
   wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
   sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
   sudo apt update
   sudo apt install -y zabbix-server-mysql zabbix-sql-scripts
   ```

2. **Import Database Schema** (**On Server A ONLY**):
   ```bash
   zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | MYSQL_PWD='VaultPasswordPlaceholder123!' mysql -h 127.0.0.1 -u zabbix zabbix
   ```

3. **Configure Zabbix Server Node A** (`/etc/zabbix/zabbix_server.conf`):
   ```ini
   DBHost=127.0.0.1
   DBName=zabbix
   DBUser=zabbix
   DBPassword=VaultPasswordPlaceholder123!
   DBPort=3306
   
   # Tuning for 4 GB RAM
   CacheSize=128M
   HistoryCacheSize=64M
   TrendCacheSize=32M
   ValueCacheSize=64M
   
   # HA Clustering
   HANodeName=mon-primary
   NodeAddress=10.0.100.10:10051
   ```
   Start service: `sudo systemctl enable zabbix-server && sudo systemctl start zabbix-server`

4. **Configure Zabbix Server Node B** (`/etc/zabbix/zabbix_server.conf`):
   ```ini
   DBHost=127.0.0.1
   DBName=zabbix
   DBUser=zabbix
   DBPassword=VaultPasswordPlaceholder123!
   DBPort=3306
   
   # Tuning for 4 GB RAM
   CacheSize=128M
   HistoryCacheSize=64M
   TrendCacheSize=32M
   ValueCacheSize=64M
   
   # HA Clustering
   HANodeName=mon-standby
   NodeAddress=10.0.100.11:10051
   ```
   Start service: `sudo systemctl enable zabbix-server && sudo systemctl start zabbix-server`

---

### 3.4 Keepalived VIP Configuration (Network HA)

1. **Install Keepalived** (Both nodes):
   ```bash
   sudo apt install -y keepalived
   ```

2. **Configure Health Check Script** (Create `/etc/keepalived/scripts/check_zabbix.sh` on both nodes):
   ```bash
   #!/bin/bash
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
   Make executable: `sudo chmod +x /etc/keepalived/scripts/check_zabbix.sh`

3. **Configure Keepalived on Server A** (`/etc/keepalived/keepalived.conf`):
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
           auth_pass VrrpPasswordHA123!
       }
       virtual_ipaddress {
           10.0.100.100/24 dev eth0
       }
       track_script {
           check_zabbix
       }
   }
   ```

4. **Configure Keepalived on Server B** (`/etc/keepalived/keepalived.conf`):
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
       priority 100
       advert_int 1
       authentication {
           auth_type PASS
           auth_pass VrrpPasswordHA123!
       }
       virtual_ipaddress {
           10.0.100.100/24 dev eth0
       }
       track_script {
           check_zabbix
       }
   }
   ```

5. **Start service**:
   ```bash
   sudo systemctl enable keepalived && sudo systemctl start keepalived
   ```

---

## 4. Configuring Monitored Target Hosts (Agents)

Monitored Linux and Windows guest nodes require the Zabbix Agent 2.

### 4.1 Linux Monitored Hosts
1. Install Repository & Agent 2:
   ```bash
   wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
   sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
   sudo apt update && sudo apt install -y zabbix-agent2
   ```
2. Generate PSK key at `/etc/zabbix/zabbix_agent2.psk`:
   ```bash
   openssl rand -hex 32 | sudo tee /etc/zabbix/zabbix_agent2.psk
   sudo chmod 440 /etc/zabbix/zabbix_agent2.psk
   sudo chown root:zabbix /etc/zabbix/zabbix_agent2.psk
   ```
3. Update `/etc/zabbix/zabbix_agent2.conf` to configure active/passive checks:
   ```ini
   Server=10.0.100.100
   ServerActive=10.0.100.100
   Hostname=monitored-linux-vm-name
   TLSConnect=psk
   TLSAccept=psk
   TLSPSKIdentity=monitoring-stack-psk
   TLSPSKFile=/etc/zabbix/zabbix_agent2.psk
   ```
4. Restart service:
   ```bash
   sudo systemctl restart zabbix-agent2
   ```

### 4.2 Windows Monitored Hosts
1. Download Zabbix Agent 2 installer MSI.
2. Silent install command:
   ```cmd
   msiexec.exe /i zabbix_agent2-7.0.0-windows-amd64-openssl.msi /qn SERVER=10.0.100.100 SERVERACTIVE=10.0.100.100 HOSTNAME=%COMPUTERNAME% TLSCONNECT=psk TLSACCEPT=psk TLSPSKIDENTITY=monitoring-stack-psk TLSPSKFILE="C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk"
   ```
3. Write same 64-character PSK hex string into `C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk`.
4. Ensure the service `Zabbix Agent 2` is set to Automatic and running.

---

## 5. Verification & Testing

### Verify Zabbix HA Cluster Nodes
Log in via SSH and run:
```bash
zabbix_server -R ha_status
```
Example Output:
```text
Failover delay: 60 seconds
Active: mon-primary [10.0.100.10:10051] (status: active, heartbeat: 2s ago)
Standby: mon-standby [10.0.100.11:10051] (status: standby, heartbeat: 4s ago)
```

### Accessing the Web Consoles
- **Zabbix Web UI**: `http://10.0.100.100/zabbix` (Credentials: `Admin` / `zabbix`).
- **Grafana Dashboards**: `http://10.0.100.100:3000` (Credentials: `admin` / `VaultGrafanaPassword123!`).
