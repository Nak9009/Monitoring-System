# Enterprise On-Premises Monitoring & Alerting System Design

> **Author:** Senior Infrastructure Architect & DevOps Engineer
> **Date:** June 2026
> **Revision:** 1.0
> **Scope:** 40 VMs (scalable to 100+), mixed OS, multi-service on-premises environment

---

## Table of Contents

1. [Recommended Monitoring Stack & Justification](#1-recommended-monitoring-stack--justification)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Network Topology](#3-network-topology)
4. [Server Sizing Recommendations](#4-server-sizing-recommendations)
5. [Agent Deployment Strategy](#5-agent-deployment-strategy)
6. [Monitoring Categories & Metrics](#6-monitoring-categories--metrics)
7. [Alerting Rules & Severity Levels](#7-alerting-rules--severity-levels)
8. [Dashboard Design](#8-dashboard-design)
9. [Database Sizing & Retention Strategy](#9-database-sizing--retention-strategy)
10. [Backup & Disaster Recovery Plan](#10-backup--disaster-recovery-plan)
11. [Security Best Practices](#11-security-best-practices)
12. [Step-by-Step Implementation Roadmap](#12-step-by-step-implementation-roadmap)
13. [Cost Estimation](#13-cost-estimation)
14. [Zabbix vs Prometheus+Grafana vs Checkmk](#14-zabbix-vs-prometheusgrafana-vs-checkmk)
15. [Enterprise-Grade Best Practices](#15-enterprise-grade-best-practices)

---

## 1. Recommended Monitoring Stack & Justification

#### Primary Stack: **Zabbix 7.x + Grafana + MySQL 8.0**

| Component | Tool | Justification |
|-----------|------|---------------|
| **Monitoring Engine** | Zabbix 7.0 LTS | Enterprise-grade, agent-based & agentless, native SNMP, auto-discovery, built-in alerting, 5-year LTS support |
| **Time-Series DB** | MySQL 8.0 | Robust performance, low overhead, replication support, tuned for memory limits (1 GB buffer pool) |
| **Visualization** | Grafana 11 OSS | Rich dashboards, Zabbix data source plugin, community templates, alerting extensions |
| **Log Aggregation** | Loki + Promtail | Lightweight log collection, label-based querying, integrates with Grafana |
| **Uptime Monitoring** | Zabbix + Uptime Kuma | External synthetic checks, status pages for stakeholders |
| **Network Monitoring** | Zabbix SNMP + LibreNMS | SNMP v2c/v3 polling, network topology mapping, flow analysis |
| **APM (Optional)** | Elastic APM or OpenTelemetry | Application performance tracing for Laravel/Node.js |

### Why Zabbix as the Core?

1. **All-in-one platform** — metrics, alerting, auto-discovery, reporting in a single tool
2. **Native agent support** — Zabbix Agent 2 (Go-based) for both Linux and Windows
3. **SNMP built-in** — No additional tools needed for network device monitoring
4. **Template ecosystem** — 500+ official templates for MySQL, Redis, RabbitMQ, Nginx, etc.
5. **Scalability** — Proven to handle 100,000+ metrics per second with Zabbix Proxy architecture
6. **No per-node licensing** — Fully open-source, unlimited hosts
7. **VMware/Proxmox integration** — Native hypervisor monitoring via API
8. **Enterprise features** — SLA reporting, maintenance windows, event correlation

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        MONITORING MANAGEMENT VLAN (10.0.100.0/24)               │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐     │
│  │                     PRIMARY MONITORING SERVER                          │     │
│  │                    (mon-primary.internal)                              │     │
│  │                                                                       │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │     │
│  │  │  Zabbix      │  │  Zabbix      │  │  Grafana     │                │     │
│  │  │  Server 7.0  │  │  Frontend    │  │  11 OSS      │                │     │
│  │  │  (Port 10051)│  │  (Nginx:443) │  │  (Port 3000) │                │     │
│  │  └──────┬───────┘  └──────────────┘  └──────┬───────┘                │     │
│  │         │                                    │                        │     │
│  │  ┌──────▼───────────────────────────────────▼───────┐                │     │
│  │  │                 MySQL 8.0 Database                        │                │     │
│  │  │                    (Port 3306)                            │                │     │
│  │  └──────────────────────────────────────────────────┘                │     │
│  │                                                                       │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │     │
│  │  │  Loki        │  │  Uptime Kuma │  │  Alertmanager│                │     │
│  │  │  (Port 3100) │  │  (Port 3001) │  │  (Telegram/  │                │     │
│  │  │              │  │              │  │   Email)     │                │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │     │
│  └─────────────────────────────────────────────────────────────────────────┘     │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐     │
│  │                     STANDBY MONITORING SERVER                          │     │
│  │                    (mon-standby.internal)                              │     │
│  │                                                                       │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │     │
│  │  │  Zabbix      │  │  MySQL       │  │  Grafana     │                │     │
│  │  │  Server      │  │  Replica     │  │  (Standby)   │                │     │
│  │  │  (Standby)   │  │  (Port 3306) │  │              │                │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │     │
│  └─────────────────────────────────────────────────────────────────────────┘     │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐     │
│  │                      ZABBIX PROXY (OPTIONAL)                           │     │
│  │                   (For remote sites / DMZ / 100+ VMs)                  │     │
│  │                                                                       │     │
│  │  ┌──────────────┐  ┌──────────────┐                                  │     │
│  │  │  Zabbix      │  │  SQLite /    │                                  │     │
│  │  │  Proxy       │  │  MySQL       │  │                                  │     │
│  │  │  (Active)    │  │  (Local)     │                                  │     │
│  │  └──────────────┘  └──────────────┘                                  │     │
│  └─────────────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌───────────────┼───────────────────┐
                    │               │                   │
                    ▼               ▼                   ▼
    ┌───────────────────┐ ┌─────────────────┐ ┌─────────────────────┐
    │  APPLICATION VLAN  │ │  DATABASE VLAN  │ │   NETWORK DEVICES   │
    │  (10.0.10.0/24)   │ │  (10.0.20.0/24) │ │   (10.0.1.0/24)    │
    │                   │ │                 │ │                     │
    │ ┌───┐ ┌───┐ ┌───┐│ │ ┌───┐ ┌───┐    │ │ ┌───┐ ┌───┐ ┌───┐  │
    │ │VM │ │VM │ │VM ││ │ │DB │ │DB │    │ │ │SW │ │RT │ │FW │  │
    │ │ 1 │ │ 2 │ │ N ││ │ │ 1 │ │ 2 │    │ │ │   │ │   │ │   │  │
    │ └─┬─┘ └─┬─┘ └─┬─┘│ │ └─┬─┘ └─┬─┘    │ │ └─┬─┘ └─┬─┘ └─┬─┘  │
    │   │     │     │   │ │   │     │      │ │   │     │     │    │
    │   ▼     ▼     ▼   │ │   ▼     ▼      │ │   ▼     ▼     ▼    │
    │  Zabbix Agent 2   │ │ Zabbix Agent 2 │ │  SNMP v2c/v3       │
    │  + Promtail       │ │ + Promtail     │ │  Polling           │
    └───────────────────┘ └─────────────────┘ └─────────────────────┘
                                     │
                                     ▼
                    ┌───────────────────────────────┐
                    │       ALERT CHANNELS          │
                    │                               │
                    │  ┌─────────┐  ┌────────────┐  │
                    │  │Telegram │  │  Email/SMTP │  │
                    │  │Bot API  │  │  (Postfix)  │  │
                    │  └─────────┘  └────────────┘  │
                    │                               │
                    │  ┌─────────┐  ┌────────────┐  │
                    │  │Webhook  │  │  PagerDuty  │  │
                    │  │(Slack)  │  │  (Optional) │  │
                    │  └─────────┘  └────────────┘  │
                    └───────────────────────────────┘
```

### Data Flow Summary

```
Monitored Host ──[Agent 2 / SNMP / API]──► Zabbix Server ──► MySQL 8.0
                                                │
                                                ├──► Zabbix Frontend (Web UI)
                                                ├──► Grafana (Dashboards)
                                                ├──► Telegram Bot (Alerts)
                                                ├──► SMTP Server (Email Alerts)
                                                └──► Loki (Log Correlation)
```

---

## 3. Network Topology

### VLAN Segmentation

| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| 100 | Monitoring | 10.0.100.0/24 | Monitoring infrastructure servers |
| 10 | Application | 10.0.10.0/24 | Laravel, Node.js, Nginx servers |
| 20 | Database | 10.0.20.0/24 | MySQL, Redis, RabbitMQ servers |
| 30 | Infrastructure | 10.0.30.0/24 | AD, DNS, DHCP, file servers |
| 1 | Management | 10.0.1.0/24 | Switches, routers, firewalls (SNMP) |
| 40 | DMZ | 10.0.40.0/24 | Public-facing services |

### Firewall Rules for Monitoring

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| All VMs | mon-primary | 10051/tcp | TCP | Zabbix Agent → Server (active checks) |
| mon-primary | All VMs | 10050/tcp | TCP | Zabbix Server → Agent (passive checks) |
| mon-primary | Network Devices | 161/udp | UDP | SNMP polling |
| Network Devices | mon-primary | 162/udp | UDP | SNMP traps |
| mon-primary | DB VLAN | 3306/tcp | TCP | MySQL monitoring |
| mon-primary | DB VLAN | 6379/tcp | TCP | Redis monitoring |
| mon-primary | DB VLAN | 5672,15672/tcp | TCP | RabbitMQ monitoring |
| mon-primary | Internet | 443/tcp | TCP | Telegram API outbound |
| mon-primary | SMTP relay | 25,587/tcp | TCP | Email alerts |
| Admin VLAN | mon-primary | 443,3000/tcp | TCP | Web UI access (Zabbix, Grafana) |
| mon-primary | Hypervisors | 443/tcp | TCP | VMware/Proxmox API |
| mon-primary | mon-standby | 3306/tcp | TCP | MySQL replication |

### DNS Records

```
mon-primary.internal.    A    10.0.100.10
mon-standby.internal.    A    10.0.100.11
mon-proxy.internal.      A    10.0.100.12
mon-vip.internal.        A    10.0.100.100   (Keepalived VIP)
grafana.internal.        CNAME mon-vip.internal.
zabbix.internal.         CNAME mon-vip.internal.
```

---

## 4. Server Sizing Recommendations

### Current Scale (40 VMs)

| Server | Role | vCPU | RAM | Disk | OS |
|--------|------|------|-----|------|-----|
| mon-primary | Zabbix Server + Frontend + Grafana + MySQL 8.0 | 8 | 4 GB | 500 GB SSD | Ubuntu 24.04 LTS |
| mon-standby | Hot Standby (all components) | 8 | 4 GB | 500 GB SSD | Ubuntu 24.04 LTS |

### Future Scale (100+ VMs)

| Server | Role | vCPU | RAM | Disk | OS |
|--------|------|------|-----|------|-----|
| mon-zabbix-01 | Zabbix Server + Frontend | 8 | 8 GB | 100 GB SSD | Ubuntu 24.04 LTS |
| mon-zabbix-02 | Zabbix Server (HA node) | 8 | 8 GB | 100 GB SSD | Ubuntu 24.04 LTS |
| mon-db-01 | MySQL Primary | 8 | 16 GB | 1 TB NVMe SSD | Ubuntu 24.04 LTS |
| mon-db-02 | MySQL Replica | 8 | 16 GB | 1 TB NVMe SSD | Ubuntu 24.04 LTS |
| mon-grafana | Grafana + Loki | 4 | 8 GB | 200 GB SSD | Ubuntu 24.04 LTS |
| mon-proxy-01 | Zabbix Proxy (remote site) | 4 | 4 GB | 50 GB SSD | Ubuntu 24.04 LTS |

### Metrics Throughput Estimation

| Scale | Hosts | Items/Host | Total Items | NVPS* | DB Growth/Day |
|-------|-------|------------|-------------|-------|---------------|
| Current | 40 | 250 | 10,000 | ~170 | ~2 GB |
| Growth | 100 | 300 | 30,000 | ~500 | ~6 GB |
| Max | 200 | 300 | 60,000 | ~1,000 | ~12 GB |

*NVPS = New Values Per Second

### MySQL 8.0 Tuning (4 GB RAM Budget)

```ini
# /etc/mysql/mysql.conf.d/zabbix.cnf
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

---

## 5. Agent Deployment Strategy

### Zabbix Agent 2 — Recommended for All Hosts

Zabbix Agent 2 is written in Go, supports plugins, and runs on both Linux and Windows.

### Linux Deployment (Ansible Playbook)

```yaml
# playbook: deploy_zabbix_agent.yml
---
- name: Deploy Zabbix Agent 2 on Linux
  hosts: all_linux
  become: yes
  vars:
    zabbix_server: "10.0.100.10"
    zabbix_server_active: "10.0.100.10"
    zabbix_agent_port: 10050

  tasks:
    - name: Add Zabbix repository
      apt:
        deb: "https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb"
      when: ansible_os_family == "Debian"

    - name: Install Zabbix Agent 2
      apt:
        name:
          - zabbix-agent2
          - zabbix-agent2-plugin-*
        state: present
        update_cache: yes

    - name: Configure Zabbix Agent 2
      template:
        src: zabbix_agent2.conf.j2
        dest: /etc/zabbix/zabbix_agent2.conf
        owner: root
        group: zabbix
        mode: '0640'
      notify: Restart zabbix-agent2

    - name: Enable and start Zabbix Agent 2
      systemd:
        name: zabbix-agent2
        enabled: yes
        state: started

  handlers:
    - name: Restart zabbix-agent2
      systemd:
        name: zabbix-agent2
        state: restarted
```

### Agent Configuration Template

```ini
# zabbix_agent2.conf.j2
Server={{ zabbix_server }}
ServerActive={{ zabbix_server_active }}
Hostname={{ ansible_hostname }}
HostMetadata=Linux {{ ansible_distribution }} {{ group_names | join(' ') }}

# TLS Configuration (PSK)
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity={{ ansible_hostname }}-psk
TLSPSKFile=/etc/zabbix/zabbix_agent2.psk

# Plugin configurations
Plugins.Mysql.Sessions.default.Uri=tcp://localhost:3306
Plugins.Mysql.Sessions.default.User=zbx_monitor
Plugins.Mysql.Sessions.default.Password={{ mysql_monitor_password }}

Plugins.Redis.Sessions.default.Uri=tcp://localhost:6379
Plugins.Redis.Sessions.default.Password={{ redis_password }}

# System limits
BufferSend=5
BufferSize=100
Timeout=10
```

### Windows Deployment (PowerShell)

```powershell
# deploy_zabbix_agent_windows.ps1
$ZabbixVersion = "7.0.0"
$ZabbixServer = "10.0.100.10"
$AgentHostname = $env:COMPUTERNAME
$InstallerUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$ZabbixVersion/zabbix_agent2-$ZabbixVersion-windows-amd64-openssl.msi"
$InstallerPath = "$env:TEMP\zabbix_agent2.msi"

# Download installer
Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath

# Silent install
Start-Process msiexec.exe -ArgumentList @(
    "/i", $InstallerPath,
    "/qn",
    "SERVER=$ZabbixServer",
    "SERVERACTIVE=$ZabbixServer",
    "HOSTNAME=$AgentHostname",
    "TLSCONNECT=psk",
    "TLSACCEPT=psk",
    "TLSPSKIDENTITY=$AgentHostname-psk",
    "TLSPSKFILE=C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk"
) -Wait -NoNewWindow

# Start service
Start-Service -Name "Zabbix Agent 2"
Set-Service -Name "Zabbix Agent 2" -StartupType Automatic
```

### Auto-Discovery Configuration

```
Zabbix Server → Configuration → Discovery Rules:

Rule 1: Linux Server Discovery
  - IP Range: 10.0.10.1-254, 10.0.20.1-254, 10.0.30.1-254
  - Check: Zabbix Agent (Port 10050)
  - Device uniqueness: Hostname
  - Action: Add host, link templates based on HostMetadata

Rule 2: Network Device Discovery
  - IP Range: 10.0.1.1-254
  - Check: SNMP v2c (community string)
  - Device uniqueness: SNMP sysName
  - Action: Add host, link SNMP template

Rule 3: VMware Discovery
  - Type: VMware
  - vCenter URL: https://vcenter.internal/sdk
  - Action: Auto-create VMs and hypervisors
```

### Host Metadata Auto-Linking Rules

| HostMetadata Contains | Auto-Link Template |
|----------------------|-------------------|
| `mysql` | Template DB MySQL by Zabbix Agent 2 |
| `redis` | Template App Redis by Zabbix Agent 2 |
| `rabbitmq` | Template App RabbitMQ by HTTP |
| `nginx` | Template App Nginx by Zabbix Agent 2 |
| `laravel` | Template App PHP-FPM + Custom Laravel |
| `nodejs` | Template App Node.js + Custom Healthcheck |
| `Windows` | Template OS Windows by Zabbix Agent 2 |
| `Linux Ubuntu` | Template OS Linux by Zabbix Agent 2 |

---

## 6. Monitoring Categories & Metrics

### 6.1 Infrastructure — VM/OS Monitoring

| Metric | Linux Item Key | Windows Item Key | Interval | Trigger Threshold |
|--------|---------------|-----------------|----------|-------------------|
| CPU Utilization | `system.cpu.util` | `system.cpu.util` | 60s | >85% for 5m |
| CPU Load (1/5/15) | `system.cpu.load[avg1]` | N/A | 60s | >nCPU×2 for 10m |
| Memory Used % | `vm.memory.utilization` | `vm.memory.utilization` | 60s | >90% for 5m |
| Swap Used | `system.swap.size[,pused]` | `system.swap.size[,pused]` | 60s | >50% |
| Disk Used % | `vfs.fs.size[/,pused]` | `vfs.fs.size[C:,pused]` | 300s | >85% |
| Disk I/O Wait | `system.cpu.util[,iowait]` | N/A | 60s | >30% for 5m |
| Disk Read/Write | `vfs.dev.read.rate` | `perf_counter_en[...]` | 60s | Trend analysis |
| Network In/Out | `net.if.in[eth0]` | `net.if.in[...]` | 60s | >80% capacity |
| Network Errors | `net.if.in[eth0,errors]` | N/A | 60s | >0 for 5m |
| Uptime | `system.uptime` | `system.uptime` | 300s | <600s (reboot) |
| Process Count | `proc.num` | `proc.num` | 60s | Anomaly detection |
| Open Files | `kernel.maxfiles` | N/A | 300s | >80% |
| NTP Offset | `system.localtime` | `system.localtime` | 300s | >3s drift |

### 6.2 Database — MySQL Monitoring

| Metric | Collection Method | Interval | Trigger |
|--------|------------------|----------|---------|
| MySQL Up/Down | `mysql.ping` | 30s | =0 → DISASTER |
| Connections Active | `mysql.global.status[Threads_connected]` | 60s | >80% max_connections |
| Queries Per Second | `mysql.global.status[Queries]` (rate) | 60s | Trend analysis |
| Slow Queries | `mysql.global.status[Slow_queries]` (rate) | 60s | >10/min |
| Replication Lag | `mysql.slave.status[Seconds_Behind_Master]` | 30s | >30s |
| Replication Status | `mysql.slave.status[Slave_IO_Running]` | 30s | ≠Yes → HIGH |
| Buffer Pool Hit Ratio | Calculated item | 300s | <95% |
| Table Locks Waited | `mysql.global.status[Table_locks_waited]` | 60s | >0/min |
| InnoDB Row Locks | `mysql.global.status[Innodb_row_lock_waits]` | 60s | Trend analysis |
| Binary Log Space | `mysql.global.status[Binlog_cache_disk_use]` | 300s | Trend analysis |
| Database Size | Custom SQL query | 3600s | >80% allocated |

### 6.3 Cache — Redis Monitoring

| Metric | Item Key | Interval | Trigger |
|--------|----------|----------|---------|
| Redis Ping | `redis.ping` | 30s | ≠1 → DISASTER |
| Connected Clients | `redis.clients.connected` | 60s | >80% maxclients |
| Memory Used | `redis.memory.used` | 60s | >80% maxmemory |
| Memory Fragmentation | `redis.memory.fragmentation_ratio` | 300s | >1.5 |
| Hit Rate | Calculated: hits/(hits+misses) | 60s | <90% |
| Evicted Keys | `redis.stats.evicted_keys` (rate) | 60s | >0/s |
| Keyspace | `redis.keyspace[db0]` | 300s | Trend analysis |
| RDB Last Save | `redis.rdb.last_bgsave_status` | 300s | ≠ok |
| Replication Offset | `redis.replication.offset` | 30s | Lag >1MB |
| Blocked Clients | `redis.clients.blocked` | 60s | >0 for 5m |

### 6.4 Message Queue — RabbitMQ Monitoring

| Metric | HTTP API Endpoint | Interval | Trigger |
|--------|------------------|----------|---------|
| Node Health | `/api/healthchecks/node` | 30s | ≠ok → DISASTER |
| Queue Message Count | `/api/queues/{vhost}/{queue}` | 30s | >10,000 |
| Queue Consumers | Per queue consumer count | 60s | =0 → HIGH |
| Message Rate (publish) | `/api/overview` message_stats | 30s | Trend analysis |
| Message Rate (deliver) | `/api/overview` message_stats | 30s | Trend analysis |
| Unacknowledged Msgs | `messages_unacknowledged` | 30s | >1,000 |
| Memory Used | `/api/nodes` mem_used | 60s | >80% mem_limit |
| Disk Free | `/api/nodes` disk_free | 60s | <disk_free_limit×2 |
| Connections | `/api/connections` count | 60s | >80% max |
| Erlang Processes | `/api/nodes` proc_used | 300s | >80% proc_total |
| Cluster Status | `/api/nodes` running | 30s | Node down → HIGH |
| File Descriptors | `/api/nodes` fd_used | 300s | >80% fd_total |

### 6.5 Application — Laravel Monitoring

| Metric | Method | Interval | Trigger |
|--------|--------|----------|---------|
| Health Endpoint | HTTP check `/api/health` | 30s | HTTP ≠200 → HIGH |
| Response Time | HTTP response time | 30s | >2s avg |
| PHP-FPM Active | `php-fpm.status[active processes]` | 30s | >80% max_children |
| PHP-FPM Queue | `php-fpm.status[listen queue]` | 30s | >0 for 5m |
| Laravel Queue Size | Custom script (Artisan) | 60s | >100 jobs |
| Failed Jobs | Custom script | 300s | >0 |
| Log Errors (5xx) | Loki log query | Real-time | >5/min |
| Session Count | Redis/DB query | 300s | Trend analysis |
| Cache Hit Rate | Custom metric | 300s | <80% |
| Scheduler Status | Process check | 60s | Not running → HIGH |

### 6.6 Application — Node.js Microservices

| Metric | Method | Interval | Trigger |
|--------|--------|----------|---------|
| Health Endpoint | HTTP `/health` or `/readyz` | 30s | ≠200 → HIGH |
| Response Time (p99) | HTTP probe / APM | 30s | >500ms |
| Event Loop Lag | `/metrics` (prom-client) | 30s | >100ms |
| Heap Used | `/metrics` memory gauge | 60s | >80% max |
| Active Handles | `/metrics` gauge | 60s | Trend analysis |
| Process Uptime | Process check | 60s | <60s (restart) |
| HTTP Error Rate | Log / APM | 30s | >1% of requests |
| Open Connections | `/metrics` gauge | 60s | Trend analysis |

### 6.7 Web Server — Nginx

| Metric | Item Key | Interval | Trigger |
|--------|----------|----------|---------|
| Nginx Status | `nginx.ping` | 30s | ≠1 → DISASTER |
| Active Connections | `nginx.connections.active` | 30s | >80% worker_connections |
| Requests/sec | `nginx.requests.total` (rate) | 30s | Trend analysis |
| 5xx Error Rate | Log parsing / stub_status | 30s | >1% → WARNING |
| Waiting Connections | `nginx.connections.waiting` | 60s | Trend analysis |
| SSL Certificate Expiry | `web.certificate.get` | 86400s | <30 days → WARNING |
| Upstream Response Time | Log parsing | 60s | >2s avg → WARNING |

### 6.8 Network Devices — SNMP

| Metric | OID / MIB | Interval | Trigger |
|--------|-----------|----------|---------|
| Device Uptime | sysUpTime (.1.3.6.1.2.1.1.3) | 300s | <600s (reboot) |
| Interface Status | ifOperStatus | 60s | Down → HIGH |
| Interface Traffic In | ifHCInOctets | 60s | >80% bandwidth |
| Interface Traffic Out | ifHCOutOctets | 60s | >80% bandwidth |
| Interface Errors | ifInErrors / ifOutErrors | 60s | >0/min |
| CPU Utilization | Vendor-specific OID | 300s | >80% |
| Memory Utilization | Vendor-specific OID | 300s | >80% |
| Temperature | entPhysicalSensorValue | 300s | >70°C |
| Fan Status | Vendor-specific | 300s | Failed → HIGH |
| Power Supply | Vendor-specific | 300s | Failed → HIGH |
| BGP/OSPF Neighbors | Routing MIB | 60s | State change → HIGH |
| ARP Table Size | ipNetToMediaTable | 300s | Trend analysis |

### 6.9 Hypervisor Monitoring

| Metric | Method | Interval | Trigger |
|--------|--------|----------|---------|
| ESXi/Proxmox Host Status | vSphere API / Proxmox API | 60s | Down → DISASTER |
| Datastore Usage | API query | 300s | >85% |
| Host CPU Usage | API query | 60s | >80% for 15m |
| Host Memory Usage | API query | 60s | >85% for 15m |
| VM Count per Host | API query | 300s | Capacity planning |
| vMotion Events | API query | 300s | Informational |
| Snapshot Age | API query | 3600s | >72h → WARNING |
| HA Cluster Status | API query | 300s | Degraded → HIGH |

---

## 7. Alerting Rules & Severity Levels

### Severity Classification

| Severity | Color | Response SLA | Notification | Description |
|----------|-------|-------------|--------------|-------------|
| **Disaster** | 🔴 Red | Immediate (<5 min) | Telegram + Email + Phone | Complete service outage, data loss risk |
| **High** | 🟠 Orange | 15 min | Telegram + Email | Significant degradation, imminent failure |
| **Average** | 🟡 Yellow | 1 hour | Telegram + Email | Performance degradation, attention needed |
| **Warning** | 🔵 Blue | 4 hours | Email only | Early warning, trend-based |
| **Information** | 🟢 Green | Next business day | Dashboard only | Informational, no action required |
| **Not Classified** | ⚪ Grey | N/A | None | Debug/development |

### Critical Alert Rules

```
# ═══════════════════════════════════════════════════════════════
# DISASTER SEVERITY — Immediate response required
# ═══════════════════════════════════════════════════════════════

TRIGGER: Host Unreachable
  Expression: nodata(agent.ping, 3m) = 1
  Severity: DISASTER
  Message: "🔴 DISASTER: Host {HOST.NAME} ({HOST.IP}) is UNREACHABLE for 3 minutes"

TRIGGER: MySQL Down
  Expression: last(mysql.ping) = 0
  Severity: DISASTER
  Recovery: last(mysql.ping) = 1
  Message: "🔴 DISASTER: MySQL is DOWN on {HOST.NAME}"

TRIGGER: Redis Down
  Expression: last(redis.ping) <> 1
  Severity: DISASTER
  Message: "🔴 DISASTER: Redis is DOWN on {HOST.NAME}"

TRIGGER: RabbitMQ Node Down
  Expression: last(rabbitmq.node.running) = 0
  Severity: DISASTER
  Message: "🔴 DISASTER: RabbitMQ node DOWN on {HOST.NAME}"

TRIGGER: Nginx Down
  Expression: last(nginx.ping) <> 1
  Severity: DISASTER
  Message: "🔴 DISASTER: Nginx is DOWN on {HOST.NAME}"

TRIGGER: Filesystem Full (>95%)
  Expression: last(vfs.fs.size[/,pused]) > 95
  Severity: DISASTER
  Message: "🔴 DISASTER: Disk usage {ITEM.LASTVALUE}% on {HOST.NAME} mount /"

# ═══════════════════════════════════════════════════════════════
# HIGH SEVERITY — Response within 15 minutes
# ═══════════════════════════════════════════════════════════════

TRIGGER: High CPU Usage
  Expression: avg(system.cpu.util, 10m) > 90
  Severity: HIGH
  Message: "🟠 HIGH: CPU at {ITEM.LASTVALUE}% for 10min on {HOST.NAME}"

TRIGGER: High Memory Usage
  Expression: last(vm.memory.utilization) > 95
  Severity: HIGH
  Message: "🟠 HIGH: Memory at {ITEM.LASTVALUE}% on {HOST.NAME}"

TRIGGER: MySQL Replication Broken
  Expression: last(mysql.slave.status[Slave_IO_Running]) <> "Yes"
  Severity: HIGH
  Message: "🟠 HIGH: MySQL replication broken on {HOST.NAME}"

TRIGGER: Application Health Check Failed
  Expression: last(web.page.get[http://localhost/api/health]) = 0
  Severity: HIGH
  Dependency: Host Unreachable (suppress if host is down)
  Message: "🟠 HIGH: Application health check FAILED on {HOST.NAME}"

TRIGGER: RabbitMQ Queue > 10,000 Messages
  Expression: last(rabbitmq.queue.messages) > 10000
  Severity: HIGH
  Message: "🟠 HIGH: Queue backlog {ITEM.LASTVALUE} on {HOST.NAME}"

TRIGGER: SSL Certificate Expires in 7 Days
  Expression: last(web.certificate.get[{$URL}]) < 7d
  Severity: HIGH
  Message: "🟠 HIGH: SSL cert for {$URL} expires in {ITEM.LASTVALUE}"

# ═══════════════════════════════════════════════════════════════
# AVERAGE SEVERITY — Response within 1 hour
# ═══════════════════════════════════════════════════════════════

TRIGGER: Disk Usage > 85%
  Expression: last(vfs.fs.size[/,pused]) > 85
  Severity: AVERAGE
  Message: "🟡 AVERAGE: Disk at {ITEM.LASTVALUE}% on {HOST.NAME}"

TRIGGER: CPU Usage > 85% for 5 minutes
  Expression: avg(system.cpu.util, 5m) > 85
  Severity: AVERAGE

TRIGGER: Memory Usage > 90%
  Expression: last(vm.memory.utilization) > 90
  Severity: AVERAGE

TRIGGER: MySQL Slow Queries > 10/min
  Expression: rate(mysql.global.status[Slow_queries], 1m) > 10
  Severity: AVERAGE

TRIGGER: Redis Memory > 80%
  Expression: (last(redis.memory.used) / last(redis.config.maxmemory)) * 100 > 80
  Severity: AVERAGE

TRIGGER: High Response Time > 2s
  Expression: avg(web.page.perf[{$URL}], 5m) > 2
  Severity: AVERAGE

# ═══════════════════════════════════════════════════════════════
# WARNING SEVERITY — Response within 4 hours
# ═══════════════════════════════════════════════════════════════

TRIGGER: Disk Usage > 75%
  Expression: last(vfs.fs.size[/,pused]) > 75
  Severity: WARNING

TRIGGER: SSL Certificate Expires in 30 Days
  Expression: last(web.certificate.get[{$URL}]) < 30d
  Severity: WARNING

TRIGGER: Swap Usage > 50%
  Expression: last(system.swap.size[,pused]) > 50
  Severity: WARNING

TRIGGER: NTP Time Drift > 3s
  Expression: abs(last(system.localtime) - now()) > 3
  Severity: WARNING

TRIGGER: MySQL Connections > 60% Max
  Expression: last(mysql.global.status[Threads_connected]) > 0.6 * last(mysql.global.variables[max_connections])
  Severity: WARNING
```

### Trigger Dependencies (Suppress Noise)

```
Host Unreachable
  └─► All application triggers on that host (suppressed)
      ├─► MySQL Down
      ├─► Redis Down
      ├─► Nginx Down
      ├─► App Health Failed
      └─► RabbitMQ Down

Network Switch Down
  └─► All hosts behind that switch (suppressed)
```

### Telegram Alert Configuration

```python
# Zabbix Media Type: Telegram
# Webhook script for rich alerts

import requests
import sys
import json

TELEGRAM_BOT_TOKEN = "{$TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID = "{$TELEGRAM_CHAT_ID}"  # Group or channel ID

severity_emoji = {
    "Disaster":    "🔴",
    "High":        "🟠",
    "Average":     "🟡",
    "Warning":     "🔵",
    "Information": "🟢",
}

def send_alert(subject, message, severity):
    emoji = severity_emoji.get(severity, "⚪")
    text = f"""
{emoji} <b>{subject}</b>

<b>Severity:</b> {severity}
<b>Host:</b> {'{HOST.NAME}'} ({'{HOST.IP}'})
<b>Time:</b> {'{EVENT.DATE}'} {'{EVENT.TIME}'}

{message}

<b>Event ID:</b> {'{EVENT.ID}'}
<b>Trigger:</b> {'{TRIGGER.NAME}'}
<b>Status:</b> {'{TRIGGER.STATUS}'}
"""

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }
    requests.post(url, json=payload)
```

### Escalation Policy

```
Minute 0:  Alert fires → Telegram (Ops Group) + Email (On-call)
Minute 15: Not acknowledged → Telegram (Ops Manager) + Email (Manager)
Minute 30: Not acknowledged → Telegram (IT Director) + Phone call
Minute 60: Not acknowledged → Telegram (C-Level) + Incident created
```

---

## 8. Dashboard Design

### Dashboard Hierarchy

```
Level 1: Executive Overview
  └─ Total hosts, % uptime, active problems, SLA compliance

Level 2: Infrastructure Overview
  ├─ Host Map (status by color)
  ├─ Top 10 CPU/Memory/Disk consumers
  └─ Network traffic overview

Level 3: Service Dashboards
  ├─ Application Dashboard (Laravel + Node.js)
  ├─ Database Dashboard (MySQL + Redis)
  ├─ Message Queue Dashboard (RabbitMQ)
  ├─ Web Server Dashboard (Nginx)
  └─ Network Dashboard (Switches, Routers, Firewalls)

Level 4: Host Detail
  └─ Per-host deep dive (all metrics)
```

### Dashboard 1: Executive Overview (Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE HEALTH                        │
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ 40       │ │ 38       │ │ 2        │ │ 99.7%    │          │
│  │ Total    │ │ Healthy  │ │ Problems │ │ Uptime   │          │
│  │ Hosts    │ │ ✅       │ │ ⚠️       │ │ (30d)    │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                 │
│  ┌───────────────────────────────────┐ ┌───────────────────────┐│
│  │     Active Problems by Severity   │ │   Problem Timeline    ││
│  │                                   │ │                       ││
│  │  🔴 Disaster: 0                  │ │  ───────────────────  ││
│  │  🟠 High:     1                  │ │  [Sparkline chart]    ││
│  │  🟡 Average:  1                  │ │                       ││
│  │  🔵 Warning:  3                  │ │                       ││
│  └───────────────────────────────────┘ └───────────────────────┘│
│                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │              HOST MAP (Status by Color)                      ││
│  │                                                              ││
│  │   [app-01]✅  [app-02]✅  [app-03]⚠️  [db-01]✅            ││
│  │   [db-02]✅   [redis-01]✅ [rmq-01]✅  [nginx-01]✅         ││
│  │   [web-01]✅  [web-02]✅  [worker-01]🔴 ...                 ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Dashboard 2: Database Dashboard (Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│                      MySQL Dashboard                            │
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ 342      │ │ 1.2K     │ │ 99.2%    │ │ 0.3s     │          │
│  │ Active   │ │ QPS      │ │ Buffer   │ │ Avg Slow │          │
│  │ Conns    │ │          │ │ Hit Rate │ │ Query    │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                 │
│  ┌─────────────────────────┐ ┌─────────────────────────────────┐│
│  │  Connections Over Time  │ │     Queries Per Second          ││
│  │  [Time series graph]    │ │     [Time series graph]         ││
│  │                         │ │     SELECT / INSERT / UPDATE    ││
│  └─────────────────────────┘ └─────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────┐ ┌─────────────────────────────────┐│
│  │  Replication Lag        │ │     InnoDB Buffer Pool          ││
│  │  [Time series graph]    │ │     [Gauge + Time series]       ││
│  └─────────────────────────┘ └─────────────────────────────────┘│
│                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │  Slow Queries Log (Last 24h)                                 ││
│  │  [Table: Time | Query | Duration | Rows Examined]            ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Dashboard 3: Application Dashboard (Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│                   Application Health                            │
│                                                                 │
│  ┌───────── Laravel ──────────┐ ┌──────── Node.js ────────────┐│
│  │ Status: ✅ Healthy         │ │ Status: ✅ Healthy           ││
│  │ Resp Time: 180ms (p95)    │ │ Resp Time: 45ms (p95)       ││
│  │ Error Rate: 0.02%         │ │ Error Rate: 0.01%            ││
│  │ Queue Jobs: 12 pending    │ │ Event Loop Lag: 2ms          ││
│  │ PHP-FPM Active: 8/50      │ │ Heap Used: 120MB/512MB       ││
│  └────────────────────────────┘ └──────────────────────────────┘│
│                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │  Request Rate & Response Time (All Services)                 ││
│  │  [Multi-line time series: req/s, p50, p95, p99]             ││
│  └──────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────┐ ┌─────────────────────────────────┐│
│  │  Error Rate by Service  │ │     Queue Depth Over Time       ││
│  │  [Stacked bar chart]    │ │     [Time series by queue]      ││
│  └─────────────────────────┘ └─────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Dashboard 4: Network & SNMP

```
┌─────────────────────────────────────────────────────────────────┐
│                    Network Overview                              │
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ 12       │ │ 11       │ │ 1        │ │ 45 Gbps  │          │
│  │ Devices  │ │ Up       │ │ Down     │ │ Total    │          │
│  │ Total    │ │ ✅       │ │ ⚠️       │ │ Traffic  │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │  Network Topology Map                                        ││
│  │  [Visual topology with traffic flow indicators]              ││
│  └──────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │  Top Interfaces by Utilization                               ││
│  │  [Horizontal bar chart: interface name → % utilization]      ││
│  └──────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │  Interface Error Rate (All Devices)                          ││
│  │  [Table: Device | Interface | In Errors | Out Errors]        ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Database Sizing & Retention Strategy

### Storage Estimation

| Parameter | Value |
|-----------|-------|
| Total monitored hosts | 40 (current), 100 (planned) |
| Average items per host | 250 |
| Total items | 10,000 (current), 30,000 (planned) |
| Average item data size | 50 bytes |
| Average collection interval | 60 seconds |
| NVPS (New Values Per Second) | ~170 (current), ~500 (planned) |

### Storage Calculation

```
Daily data volume = NVPS × 86,400 seconds × 50 bytes per value

Current (170 NVPS):
  Raw:   170 × 86,400 × 50 = ~700 MB/day
  With indexes & overhead: ~2 GB/day

Future (500 NVPS):
  Raw:   500 × 86,400 × 50 = ~2.1 GB/day
  With indexes & overhead: ~6 GB/day
```

### Retention Policy (Tiered)

| Data Type | Retention | Interval | Storage Impact |
|-----------|-----------|----------|----------------|
| **Raw data** (history) | 30 days | Original (30-60s) | ~60 GB (current) |
| **Hourly trends** | 365 days | 1 hour aggregated | ~15 GB |
| **Daily trends** | 3 years | 1 day aggregated | ~5 GB |
| **Event/alerts** | 365 days | N/A | ~2 GB |
| **Total (Year 1)** | — | — | **~82 GB** |

### TimescaleDB Compression Strategy

```sql
-- Enable compression on Zabbix history tables
-- TimescaleDB can achieve 10:1 compression ratio

-- Convert to hypertable
SELECT create_hypertable('history', 'clock',
    chunk_time_interval => 86400,  -- 1 day chunks
    migrate_data => true);

SELECT create_hypertable('history_uint', 'clock',
    chunk_time_interval => 86400,
    migrate_data => true);

-- Add compression policy (compress after 7 days)
ALTER TABLE history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'itemid',
    timescaledb.compress_orderby = 'clock DESC'
);

SELECT add_compression_policy('history', INTERVAL '7 days');
SELECT add_compression_policy('history_uint', INTERVAL '7 days');

-- Add retention policy (drop raw data after 30 days, keep trends)
SELECT add_retention_policy('history', INTERVAL '30 days');
SELECT add_retention_policy('history_uint', INTERVAL '30 days');
SELECT add_retention_policy('history_str', INTERVAL '30 days');
SELECT add_retention_policy('history_log', INTERVAL '14 days');
SELECT add_retention_policy('history_text', INTERVAL '14 days');
```

### Disk Space Planning

| Timeframe | Raw Data | Compressed | Trends | Total |
|-----------|----------|------------|--------|-------|
| Month 1 | 60 GB | 6 GB | 1.3 GB | ~67 GB |
| Month 6 | 60 GB* | 36 GB | 7.5 GB | ~104 GB |
| Year 1 | 60 GB* | 72 GB | 15 GB | ~147 GB |
| Year 2 (100 VMs) | 180 GB* | 216 GB | 45 GB | ~441 GB |

*Raw data stays constant due to 30-day retention

> [!TIP]
> With TimescaleDB compression, the effective storage drops significantly. Allocate **500 GB SSD** for the current deployment and plan for **1 TB** when scaling to 100+ VMs.

---

## 10. Backup & Disaster Recovery Plan

### Backup Strategy

| Component | Method | Frequency | Retention | Target |
|-----------|--------|-----------|-----------|--------|
| MySQL DB | `mysqldump` (full) | Daily full | 30 days | NFS/NAS + Off-site |
| Zabbix Config | `zabbix_export` API (templates, hosts) | Daily | 90 days | Git repository |
| Grafana Dashboards | Grafana API export (JSON) | Daily | 90 days | Git repository |
| Server Config | Ansible playbooks + /etc backup | On change | Indefinite | Git repository |
| TLS/PSK Keys | Encrypted archive | Weekly | 90 days | Vault/encrypted NAS |

### Automated Backup Script

```bash
#!/bin/bash
# /opt/monitoring/scripts/backup.sh
# Run via cron: 0 2 * * * /opt/monitoring/scripts/backup.sh

set -euo pipefail

BACKUP_DIR="/backup/monitoring/$(date +%Y%m%d)"
RETENTION_DAYS=30
DB_NAME="zabbix"
DB_USER="zabbix"
REMOTE_BACKUP="nfs-server:/backup/monitoring"

mkdir -p "$BACKUP_DIR"

# 1. MySQL full backup (compressed)
echo "[$(date)] Starting MySQL backup..."
MYSQL_PWD="YourVaultPasswordHere" mysqldump -u "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_DIR/zabbix_db_$(date +%Y%m%d_%H%M%S).sql.gz"

# 2. Zabbix configuration export (via API)
echo "[$(date)] Exporting Zabbix configuration..."
python3 /opt/monitoring/scripts/zabbix_config_export.py --output "$BACKUP_DIR/zabbix_config/"

# 3. Grafana dashboard export
echo "[$(date)] Exporting Grafana dashboards..."
for dash in $(curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    http://localhost:3000/api/search | jq -r '.[].uid'); do
    curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
        "http://localhost:3000/api/dashboards/uid/$dash" \
        > "$BACKUP_DIR/grafana_dashboards/${dash}.json"
done

# 4. Configuration files
echo "[$(date)] Backing up configuration files..."
tar czf "$BACKUP_DIR/config_backup.tar.gz" \
    /etc/zabbix/ \
    /etc/grafana/ \
    /etc/nginx/sites-available/ \
    /etc/mysql/

# 5. Copy to remote storage
echo "[$(date)] Syncing to remote storage..."
rsync -avz --delete "$BACKUP_DIR" "$REMOTE_BACKUP/"

# 6. Clean up old backups
echo "[$(date)] Cleaning backups older than $RETENTION_DAYS days..."
find /backup/monitoring/ -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

# 7. Verify backup integrity
echo "[$(date)] Verifying backup..."
gunzip -t "$BACKUP_DIR"/zabbix_db_*.sql.gz > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[$(date)] ✅ Backup verification PASSED"
else
    echo "[$(date)] ❌ Backup verification FAILED"
    # Send alert
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=🔴 BACKUP FAILED: Monitoring server backup verification failed on $(hostname)"
fi

echo "[$(date)] Backup completed successfully."
```

### High Availability Architecture

```
                    ┌────────────────┐
                    │   Keepalived   │
                    │  VIP: .100     │
                    └───────┬────────┘
                            │
               ┌────────────┼────────────┐
               │                         │
    ┌──────────▼──────────┐  ┌──────────▼──────────┐
    │   mon-primary       │  │   mon-standby        │
    │   10.0.100.10       │  │   10.0.100.11        │
    │                     │  │                      │
    │  Zabbix Server      │  │  Zabbix Server       │
    │  (ACTIVE)           │  │  (STANDBY)           │
    │                     │  │                      │
    │  MySQL              │──│  MySQL               │
    │  (PRIMARY)          │  │  (REPLICA)           │
    │                     │  │                      │
    │  Grafana            │  │  Grafana              │
    │  (ACTIVE)           │  │  (STANDBY)            │
    └─────────────────────┘  └──────────────────────┘

    Failover: Keepalived monitors Zabbix process
    → VIP moves to standby
    → MySQL promotes replica (removes read_only)
    → Zabbix starts on standby
    → RTO: < 2 minutes
```

### Disaster Recovery Runbook

| Step | Action | RTO |
|------|--------|-----|
| 1 | Detect primary failure (automatic via Keepalived) | 30s |
| 2 | VIP failover to standby node | 10s |
| 3 | Promote MySQL replica to primary (remove read_only) | 30s |
| 4 | Start Zabbix Server on standby | 60s |
| 5 | Verify monitoring resumes | 30s |
| **Total** | **Automatic failover** | **< 3 minutes** |

### Full Disaster Recovery (Site Loss)

| Step | Action | RTO |
|------|--------|-----|
| 1 | Provision new VM from template | 30 min |
| 2 | Install Zabbix + MySQL + Grafana (Ansible) | 30 min |
| 3 | Restore MySQL from backup | 1-2 hours |
| 4 | Restore Zabbix/Grafana configuration | 15 min |
| 5 | Redeploy agents (Ansible) | 30 min |
| 6 | Verify all hosts reporting | 15 min |
| **Total** | **Full rebuild from backup** | **< 4 hours** |

---

## 11. Security Best Practices

### Authentication & Access Control

| Control | Implementation |
|---------|---------------|
| **Zabbix Authentication** | LDAP/Active Directory integration, 2FA via TOTP |
| **Grafana Authentication** | LDAP/AD + OAuth2, enforce 2FA |
| **Role-Based Access** | Admin (full), Operator (view + ack), Viewer (read-only) |
| **API Access** | Token-based auth, per-user API tokens with expiry |
| **Password Policy** | Min 14 chars, complexity requirements, 90-day rotation |
| **Session Management** | 30-min timeout, single session enforcement |

### Network Security

```
# Agent Communication Security
┌────────────────────────────────────────────────┐
│  All Zabbix Agent ↔ Server communication       │
│  encrypted via TLS-PSK (Pre-Shared Key)        │
│                                                │
│  TLSConnect=psk                                │
│  TLSAccept=psk                                 │
│  TLSPSKIdentity=<unique-per-host>             │
│  TLSPSKFile=/etc/zabbix/zabbix_agent2.psk     │
│                                                │
│  PSK Key Generation:                           │
│  openssl rand -hex 32 > /etc/zabbix/agent.psk │
└────────────────────────────────────────────────┘
```

| Security Layer | Implementation |
|---------------|---------------|
| **Agent ↔ Server** | TLS-PSK (minimum) or TLS certificates (recommended) |
| **SNMP** | SNMPv3 with authPriv (SHA-256 + AES-256) |
| **Web UI** | HTTPS only (TLS 1.2+), HSTS enabled |
| **Database** | Listen on localhost only, SSL for replication |
| **Firewall** | Whitelist monitoring VLAN, deny all by default |
| **API** | Rate limiting, IP whitelist for automation |

### SNMP v3 Configuration

```
# On network devices:
snmp-server user zbx-monitor zbx-group v3 auth sha256 <AUTH_PASS> priv aes256 <PRIV_PASS>
snmp-server group zbx-group v3 priv read zbx-view

# In Zabbix:
SNMP Version: v3
Security Name: zbx-monitor
Security Level: authPriv
Authentication Protocol: SHA256
Authentication Passphrase: <stored in Zabbix vault>
Privacy Protocol: AES256
Privacy Passphrase: <stored in Zabbix vault>
```

### Hardening Checklist

- [x] Disable Zabbix guest access
- [x] Change default admin password immediately
- [x] Enable HTTPS with valid internal CA certificate
- [x] Configure CSP headers for web frontend
- [x] Restrict database access to localhost + replication peer
- [x] Use dedicated monitoring user accounts (least privilege) for MySQL, Redis, RabbitMQ
- [x] Rotate PSK keys annually
- [x] Audit log enabled for all configuration changes
- [x] Disable unnecessary Zabbix agent remote commands
- [x] `AllowKey=` whitelist instead of `DenyKey=` blacklist
- [x] Regular vulnerability scanning of monitoring servers
- [x] Keep Zabbix and all components patched (subscribe to security advisories)

### Monitoring User Privileges (MySQL Example)

```sql
-- Least privilege monitoring user
CREATE USER 'zbx_monitor'@'localhost' IDENTIFIED BY '<strong_password>';

GRANT USAGE, REPLICATION CLIENT, PROCESS ON *.* TO 'zbx_monitor'@'localhost';
GRANT SELECT ON performance_schema.* TO 'zbx_monitor'@'localhost';
GRANT SELECT ON mysql.* TO 'zbx_monitor'@'localhost';

-- Do NOT grant: INSERT, UPDATE, DELETE, DROP, ALTER, CREATE
```

---

## 12. Step-by-Step Implementation Roadmap

### Phase Overview

```
Phase 1 (Week 1-2):   Foundation — Server setup, Zabbix core, MySQL
Phase 2 (Week 3-4):   Agent Deployment — Linux & Windows agents across all VMs
Phase 3 (Week 5-6):   Service Monitoring — MySQL, Redis, RabbitMQ, Apps
Phase 4 (Week 7-8):   Network & Visualization — SNMP, Grafana, Dashboards
Phase 5 (Week 9-10):  Alerting & Integration — Telegram, Email, Escalation
Phase 6 (Week 11-12): HA, Security, Documentation — Standby, hardening
```

### Detailed Implementation Plan

#### Phase 1: Foundation (Week 1-2)

| Day | Task | Details |
|-----|------|---------|
| 1-2 | **Provision monitoring VMs** | Create mon-primary (8 vCPU, 4GB, 500GB SSD) and mon-standby |
| 2-3 | **Install Ubuntu 24.04 LTS** | Hardened base image, CIS benchmarks |
| 3 | **Install MySQL 8.0** | Configure tuning parameters, create zabbix database & user |
| 3 | **Configure permissions** | Configure replication & monitor users, enable log_bin_trust_function_creators |
| 4 | **Install Zabbix Server 7.0 LTS** | From official repository, connect to MySQL |
| 4 | **Install Zabbix Frontend** | Nginx + PHP-FPM, configure HTTPS |
| 5 | **Initial configuration** | Admin password, authentication, time zone |
| 5 | **Import official templates** | OS Linux, OS Windows, MySQL, Redis, etc. |
| 6-7 | **Create custom templates** | Laravel health, Node.js health, custom items |
| 8-9 | **Install Grafana 11** | Configure Zabbix data source plugin |
| 10 | **Verify & test** | Smoke test all components, check logs |

#### Phase 2: Agent Deployment (Week 3-4)

| Day | Task | Details |
|-----|------|---------|
| 11-12 | **Create Ansible playbooks** | Agent deployment for Linux and Windows |
| 12 | **Generate PSK keys** | Unique PSK per host, distribute securely |
| 13 | **Deploy to pilot group** | 5 Linux VMs, verify data collection |
| 14 | **Deploy to all Linux VMs** | Roll out across application and database tiers |
| 15-16 | **Deploy to Windows VMs** | PowerShell script or GPO deployment |
| 17 | **Configure auto-discovery** | IP range scans, host metadata linking |
| 18-19 | **Verify all hosts** | Confirm data flowing, tune intervals |
| 20 | **Setup host groups** | By environment, OS, role, location |

#### Phase 3: Service Monitoring (Week 5-6)

| Day | Task | Details |
|-----|------|---------|
| 21-22 | **MySQL monitoring** | Create zbx_monitor user, link template, verify items |
| 23 | **Redis monitoring** | Configure Agent 2 plugin, link template |
| 24 | **RabbitMQ monitoring** | HTTP API monitoring user, link template |
| 25-26 | **Nginx monitoring** | Enable stub_status, configure monitoring |
| 27-28 | **Laravel monitoring** | Create health endpoint, PHP-FPM status, queue checks |
| 29-30 | **Node.js monitoring** | Health endpoints, prom-client metrics |
| 30 | **Web scenario monitoring** | HTTP checks for critical URLs |

#### Phase 4: Network & Visualization (Week 7-8)

| Day | Task | Details |
|-----|------|---------|
| 31-32 | **SNMP configuration** | Configure SNMPv3 on all network devices |
| 33-34 | **Network device templates** | Switches, routers, firewalls SNMP monitoring |
| 35-36 | **Hypervisor monitoring** | VMware/Proxmox API integration |
| 37-38 | **Build Grafana dashboards** | Executive, Infrastructure, Application, Database |
| 39 | **Install Uptime Kuma** | External synthetic checks, status page |
| 40 | **Install Loki + Promtail** | Log aggregation from all servers |

#### Phase 5: Alerting & Integration (Week 9-10)

| Day | Task | Details |
|-----|------|---------|
| 41-42 | **Create Telegram bot** | Register with BotFather, create group |
| 42-43 | **Configure alert actions** | Severity-based routing, messages formatting |
| 44 | **Configure email alerts** | SMTP integration, HTML templates |
| 45-46 | **Build trigger rules** | All tiers: infrastructure, services, apps |
| 47-48 | **Configure escalations** | Time-based escalation policy |
| 49 | **Trigger dependencies** | Suppress cascading alerts |
| 50 | **Alert testing** | Simulate failures, verify all channels |

#### Phase 6: HA, Security & Documentation (Week 11-12)

| Day | Task | Details |
|-----|------|---------|
| 51-52 | **MySQL active-standby replication** | Setup replica on mon-standby |
| 53 | **Install Keepalived** | VIP failover between primary and standby |
| 54 | **Configure Zabbix HA** | Standby node configuration |
| 55 | **Security hardening** | TLS, SNMP v3, firewall rules, audit log |
| 56-57 | **Backup automation** | Backup scripts, cron jobs, verification |
| 58 | **Failover testing** | Simulate primary failure, measure RTO |
| 59 | **Documentation** | Runbooks, architecture docs, user guides |
| 60 | **Team training** | Knowledge transfer, ops procedures |

---

## 13. Cost Estimation

### Hardware Costs (On-Premises)

> [!NOTE]
> Zabbix, Grafana, MySQL, Loki, and Uptime Kuma are all **open-source and free**. The only costs are hardware/infrastructure and staff time.

| Item | Specification | Qty | Unit Cost (USD) | Total (USD) |
|------|--------------|-----|----------------|-------------|
| **Primary monitoring VM** | 8 vCPU, 4GB RAM, 500GB SSD | 1 | $0* | $0 |
| **Standby monitoring VM** | 8 vCPU, 4GB RAM, 500GB SSD | 1 | $0* | $0 |
| **NAS storage for backups** | 2TB usable (already exists) | — | $0* | $0 |
| **SSL certificates** | Internal CA (free) | — | $0 | $0 |

*Assuming VMs run on existing hypervisor infrastructure with available capacity.

### Software Licensing Costs

| Software | License | Annual Cost |
|----------|---------|-------------|
| Zabbix Server 7.0 LTS | GPL v2 (Free) | $0 |
| MySQL 8.0 Community | GPL (Free) | $0 |
| Grafana 11 OSS | AGPL v3 (Free) | $0 |
| Loki | AGPL v3 (Free) | $0 |
| Uptime Kuma | MIT (Free) | $0 |
| Ubuntu 24.04 LTS | Free | $0 |
| **Total Software** | | **$0** |

### Operational Costs

| Item | Details | Annual Cost (USD) |
|------|---------|-------------------|
| **Power & cooling** | 2 additional VMs (~400W total) | ~$500 |
| **Storage (incremental)** | ~500 GB SSD + backup storage | ~$200 |
| **Telegram Bot** | Free tier (sufficient for alerts) | $0 |
| **SMTP relay** | Internal Postfix or existing relay | $0 |
| **Staff time (implementation)** | 1 engineer × 12 weeks (part-time) | ~$15,000-25,000 |
| **Staff time (ongoing ops)** | ~4 hours/week maintenance | ~$10,000-15,000/yr |

### Total Cost Summary

| Category | Year 1 | Year 2+ (Annual) |
|----------|--------|-------------------|
| Hardware/Infrastructure | ~$700 | ~$700 |
| Software Licensing | $0 | $0 |
| Implementation (one-time) | $15,000-25,000 | $0 |
| Ongoing Operations | $10,000-15,000 | $10,000-15,000 |
| **Total** | **$25,700-40,700** | **$10,700-15,700** |

### Optional Paid Add-ons

| Service | Purpose | Annual Cost |
|---------|---------|-------------|
| Zabbix Enterprise Support | Vendor SLA support | ~$5,000-15,000 |
| Grafana Cloud (Teams) | Managed Grafana + alerting | ~$3,000-8,000 |
| PagerDuty / OpsGenie | On-call management | ~$2,000-5,000 |
| External uptime monitoring | StatusCake / Uptime Robot Pro | ~$200-500 |

---

## 14. Zabbix vs Prometheus+Grafana vs Checkmk

### Comparison Matrix

| Feature | Zabbix 7.0 | Prometheus + Grafana | Checkmk 2.3 |
|---------|------------|---------------------|-------------|
| **Architecture** | Centralized server + agents | Pull-based + exporters | Server + agents |
| **Data Model** | Item-based, key-value | Time-series, labels | Host/service checks |
| **SNMP Support** | ✅ Native, excellent | ⚠️ Via snmp_exporter (limited) | ✅ Native |
| **Agent (Linux)** | ✅ Zabbix Agent 2 (Go) | ⚠️ node_exporter + many others | ✅ Checkmk Agent |
| **Agent (Windows)** | ✅ Native agent | ⚠️ windows_exporter | ✅ Native agent |
| **Auto-Discovery** | ✅ Built-in, powerful | ⚠️ Service discovery (K8s-focused) | ✅ Built-in |
| **VMware Monitoring** | ✅ Native integration | ⚠️ vmware_exporter (community) | ✅ Native (vSphere) |
| **MySQL Monitoring** | ✅ Agent 2 plugin | ✅ mysqld_exporter | ✅ Plugin |
| **Redis Monitoring** | ✅ Agent 2 plugin | ✅ redis_exporter | ✅ Plugin |
| **RabbitMQ Monitoring** | ✅ HTTP template | ✅ rabbitmq_exporter | ✅ Plugin |
| **Alerting** | ✅ Built-in, advanced | ⚠️ Alertmanager (separate) | ✅ Built-in |
| **Telegram Integration** | ✅ Native media type | ⚠️ Alertmanager webhook | ⚠️ Plugin/script |
| **Dashboards** | ⚠️ Basic built-in | ✅ Grafana (excellent) | ⚠️ Basic built-in |
| **SLA Reporting** | ✅ Built-in | ❌ Not native | ✅ Built-in |
| **Event Correlation** | ✅ Built-in | ❌ Manual rules | ⚠️ Basic |
| **Maintenance Windows** | ✅ Built-in | ❌ Manual silences | ✅ Built-in |
| **Scalability** | ✅ Proxy architecture | ✅ Federation/Thanos | ⚠️ Distributed (Enterprise) |
| **HA** | ✅ Native (7.0+) | ✅ Thanos/Cortex | ⚠️ Enterprise only |
| **Learning Curve** | Medium | High (many components) | Low-Medium |
| **Community** | Large, enterprise-focused | Massive, cloud-native | Moderate |
| **Best For** | On-premises, mixed env | Kubernetes, cloud-native | IT operations, MSPs |
| **License** | GPL v2 (fully open) | Apache 2.0 | GPL v2 + Enterprise |
| **Enterprise Cost** | Free (support optional) | Free (Grafana Cloud paid) | €€€ (Enterprise features) |

### Detailed Pros & Cons

#### Zabbix 7.0

**✅ Pros:**
- All-in-one solution: monitoring, alerting, reporting, auto-discovery
- Best-in-class SNMP support for network devices
- Native VMware/Proxmox hypervisor monitoring
- Built-in SLA reporting and maintenance windows
- Single database for everything (simpler operations)
- Excellent template ecosystem (500+ official templates)
- No per-node licensing, fully open-source
- Agent 2 written in Go (fast, low resource)
- Built-in HA cluster support (Zabbix 7.0)
- Trigger dependencies reduce alert noise
- 5-year LTS support cycle
- Strong enterprise adoption and documentation

**❌ Cons:**
- Web UI is functional but not visually modern
- Custom metric collection requires item/trigger configuration (not as flexible as PromQL)
- Less suited for Kubernetes/container-native monitoring
- Single-threaded history syncer can bottleneck at extreme scale
- PHP-based frontend can be slow with many concurrent users
- Steeper initial setup compared to Checkmk
- Does not natively support metric labels (unlike Prometheus)

#### Prometheus + Grafana

**✅ Pros:**
- Industry standard for cloud-native and Kubernetes
- Powerful query language (PromQL)
- Pull-based model scales well with service discovery
- Massive exporter ecosystem (200+ exporters)
- Grafana provides best-in-class visualization
- Excellent for microservices and containerized workloads
- Strong community and integration ecosystem
- Works seamlessly with OpenTelemetry
- Time-series optimized storage (TSDB)
- Label-based data model is very flexible

**❌ Cons:**
- **Not an all-in-one solution** — requires assembling multiple components:
  - Prometheus (metrics) + Alertmanager (alerts) + Grafana (dashboards) + Loki (logs) + exporters
- Weak SNMP support (snmp_exporter is complex to configure)
- No native auto-discovery for traditional infrastructure
- No built-in SLA reporting or maintenance windows
- Each exporter runs as a separate process (management overhead)
- Pull-based model doesn't work well through firewalls/NAT
- Prometheus is not designed for long-term storage (needs Thanos/Cortex)
- Higher operational complexity (more moving parts to maintain)
- No centralized configuration management
- Windows support is limited compared to Zabbix
- VMware monitoring requires community-maintained exporters

#### Checkmk 2.3

**✅ Pros:**
- Easiest to set up and operate (great auto-detection)
- Clean, modern web interface
- Strong out-of-box monitoring (detects services automatically)
- Good for managed service providers (MSP)
- Built-in agent with auto-registration
- Good SNMP support
- Comprehensive monitoring from first install
- Bakery system for easy agent customization

**❌ Cons:**
- **Dual licensing** — Free (Raw) edition lacks key features:
  - No distributed monitoring
  - No HA
  - No reporting
  - Limited API
- Enterprise edition is expensive (€€€ per host/year)
- Smaller community compared to Zabbix and Prometheus
- Configuration via WATO can be rigid
- Less flexible for custom integrations
- Limited Kubernetes support in free edition
- Nagios-based architecture can feel dated
- Template sharing ecosystem is smaller

### Recommendation Matrix

| Scenario | Recommended Tool |
|----------|-----------------|
| On-premises, mixed Linux/Windows, SNMP devices | **Zabbix** ✅ |
| Kubernetes-first, cloud-native, microservices | **Prometheus + Grafana** |
| Small team, need quick setup, traditional IT | **Checkmk** |
| Hybrid (on-prem + cloud) | **Zabbix + Grafana** |
| Budget-conscious, no licensing fees | **Zabbix** ✅ |
| Best visualizations and dashboards | **Prometheus + Grafana** (or Zabbix + Grafana) |
| Need vendor support with SLA | **Zabbix** (support plans) or **Checkmk Enterprise** |

### Final Recommendation for This Environment

> [!IMPORTANT]
> **Zabbix 7.0 LTS + Grafana 11** is the optimal choice for this environment because:
> 1. Mixed OS environment (Linux + Windows) — Zabbix Agent 2 covers both natively
> 2. Network devices (SNMP) — Zabbix has the best SNMP support
> 3. VMware/Proxmox — Zabbix has native hypervisor integration
> 4. On-premises — Zabbix is designed for traditional infrastructure
> 5. Budget — Fully free with no licensing limitations
> 6. Scaling to 100+ VMs — Zabbix Proxy architecture handles this easily
> 7. Grafana adds world-class visualization on top of Zabbix's data collection engine

---

## 15. Enterprise-Grade Best Practices

### 15.1 Naming Conventions

```
Host naming:    {environment}-{role}-{instance}
                prod-web-01, prod-db-01, prod-app-03
                stg-web-01, dev-app-01

Host groups:    {Environment}/{OS}/{Role}
                Production/Linux/Web Servers
                Production/Windows/Application Servers
                Production/Network/Core Switches

Template naming: Template {Category} {Application} by {Method}
                 Template DB MySQL by Zabbix Agent 2
                 Template App Laravel Custom by HTTP
                 Template Net Cisco by SNMPv3

Trigger naming:  {Host group}: {Metric} is {condition}
                 MySQL: Replication lag is above 30 seconds
                 Linux: Disk space is above 85% on {#FSNAME}
```

### 15.2 Change Management

| Process | Implementation |
|---------|---------------|
| **Template changes** | Test in staging → Peer review → Deploy to production |
| **Trigger threshold changes** | Document justification → Approval → Change window |
| **Agent updates** | Rolling deployment via Ansible, 10% → 50% → 100% |
| **Configuration as Code** | Export templates/config to Git, PR-based workflow |
| **Audit trail** | Zabbix audit log + Git history |

### 15.3 Capacity Planning Framework

```
Monthly Capacity Report:
├── Current resource utilization (avg, peak, p95)
├── Growth trend analysis (linear regression)
├── Projected exhaustion date per resource
├── Recommendations (add capacity, optimize, decommission)
└── Forecast for next 3/6/12 months

Grafana Dashboard Panels:
├── CPU trend with forecast (linear prediction)
├── Memory trend with forecast
├── Disk growth rate and estimated full date
├── Network bandwidth utilization trend
└── VM count growth trajectory
```

### 15.4 Maintenance Windows

```
# Scheduled maintenance to suppress alerts during planned work

Zabbix → Configuration → Maintenance:

Name: Monthly Patching Window
Type: With data collection (continue monitoring, suppress alerts)
Active since: First Saturday, 22:00
Active till: First Sunday, 06:00
Host groups: Production/Linux/*

Name: Database Maintenance
Type: No data collection
Active since: As scheduled
Active till: As scheduled
Hosts: prod-db-01, prod-db-02
```

### 15.5 SLA Reporting Configuration

```
Zabbix → Services → SLA:

Service Tree:
├── Business Services
│   ├── Customer Portal (99.9% SLA)
│   │   ├── prod-web-01 (Nginx)
│   │   ├── prod-app-01 (Laravel)
│   │   ├── prod-app-02 (Laravel)
│   │   ├── prod-db-01 (MySQL Primary)
│   │   └── prod-redis-01 (Redis)
│   │
│   ├── API Gateway (99.9% SLA)
│   │   ├── prod-api-01 (Node.js)
│   │   ├── prod-api-02 (Node.js)
│   │   └── prod-rmq-01 (RabbitMQ)
│   │
│   └── Internal Tools (99.5% SLA)
│       ├── prod-tools-01
│       └── prod-tools-02

SLA Calculation: Based on trigger severity ≥ High
Reporting: Weekly PDF + Monthly management report
```

### 15.6 Documentation Requirements

| Document | Content | Update Frequency |
|----------|---------|-----------------|
| **Architecture Diagram** | Full monitoring topology | On change |
| **Host Inventory** | All monitored hosts, IPs, roles | Quarterly |
| **Runbook: Alert Response** | Per-alert type response procedures | On change |
| **Runbook: Failover** | Step-by-step HA failover procedure | Quarterly drill |
| **Runbook: Backup/Restore** | Backup verification and restore steps | Monthly test |
| **Template Catalog** | List of all templates and their purpose | On change |
| **Contact Matrix** | Escalation contacts by severity/service | Monthly |
| **Change Log** | All monitoring system changes | Every change |

### 15.7 Monitoring the Monitoring (Meta-Monitoring)

> [!CAUTION]
> Your monitoring system is a critical dependency. If it fails silently, you lose visibility into your entire infrastructure.

| What to Monitor | How | Alert Channel |
|----------------|-----|---------------|
| Zabbix Server process | Uptime Kuma external check | Telegram (separate bot) |
| Zabbix NVPS rate | Internal item `zabbix[wcache,values]` | Email to ops manager |
| MySQL replication lag | Standby server check | Telegram |
| Disk space on monitoring server | Local agent | Telegram + Email |
| Zabbix queue size | `zabbix[queue,10m]` | Telegram (>100 = WARNING) |
| Backup success/failure | Backup script exit code | Telegram |
| SSL certificate expiry (Zabbix UI) | External check | Email |
| Grafana availability | Uptime Kuma | Telegram |

### 15.8 Performance Optimization Tips

```
1. Use Active Agent Checks (ServerActive) instead of passive
   → Reduces Zabbix Server poller load by 50%+

2. Tune item intervals appropriately:
   - Critical health: 30s
   - Performance metrics: 60s
   - Capacity metrics: 300s
   - Configuration items: 3600s

3. Use Zabbix Preprocessing:
   → Regex, JSONPath, JavaScript preprocessing on the agent side
   → Reduces server processing load

4. Enable value caching:
   CacheSize=512M          # In zabbix_server.conf
   HistoryCacheSize=256M
   TrendCacheSize=64M
   ValueCacheSize=256M

5. Use Zabbix Proxy for 100+ hosts:
   → Offloads data collection from central server
   → Buffers data during network outages
   → Reduces central server load by 70%

6. MySQL maintenance:
   - OPTIMIZE TABLE monthly (for fragmented tables)
   - Monitor InnoDB buffer pool hit ratio (>99% target)
   - Enable slow query log (`long_query_time = 3`) to identify bottlenecks
   - Weekly verification of backups (`gunzip -t` testing)
```

### 15.9 Integration Architecture

```
                    ┌──────────────────────┐
                    │    Zabbix Server     │
                    └──────────┬───────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
     ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐
     │  Telegram   │   │   Email     │   │  Webhooks   │
     │  Bot API    │   │   SMTP      │   │             │
     └─────────────┘   └─────────────┘   └──────┬──────┘
                                                 │
                               ┌──────────────────┼────────────┐
                               │                  │            │
                        ┌──────▼──────┐   ┌──────▼────┐ ┌────▼─────┐
                        │  Incident   │   │  CMDB     │ │ Custom   │
                        │  Management │   │  Update   │ │ Scripts  │
                        │  (JIRA/     │   │  (Auto)   │ │ (Auto-   │
                        │   ServiceNow│   │           │ │  remediate│
                        └─────────────┘   └───────────┘ └──────────┘
```

### 15.10 Auto-Remediation Examples (Advanced)

```bash
# Example: Auto-restart Nginx if down for >2 minutes
# Zabbix Action → Remote Command

# Trigger: Nginx is down
# Conditions: Maintenance period = not in maintenance
# Operations: Run remote command on {HOST.HOST}

# Command:
systemctl restart nginx
sleep 5
if systemctl is-active --quiet nginx; then
    echo "Nginx auto-remediated successfully"
else
    echo "Nginx auto-remediation FAILED - manual intervention required"
    exit 1
fi
```

> [!WARNING]
> Auto-remediation should only be enabled for well-understood failure modes. Always log remediation actions and notify the operations team. Start with notification-only, then add auto-remediation gradually after analyzing patterns.

---

## Appendix A: Quick Reference — Key Ports

| Port | Protocol | Service | Direction |
|------|----------|---------|-----------|
| 10050 | TCP | Zabbix Agent (passive) | Server → Agent |
| 10051 | TCP | Zabbix Agent (active) / Trapper | Agent → Server |
| 3306 | TCP | MySQL | Internal |
| 3000 | TCP | Grafana | Admin → Server |
| 443 | TCP | Zabbix Frontend (HTTPS) | Admin → Server |
| 161 | UDP | SNMP polling | Server → Device |
| 162 | UDP | SNMP traps | Device → Server |
| 3100 | TCP | Loki (log ingestion) | Promtail → Loki |

## Appendix B: Key Configuration Files

| File | Path | Purpose |
|------|------|---------|
| Zabbix Server | `/etc/zabbix/zabbix_server.conf` | Core server configuration |
| Zabbix Frontend | `/etc/zabbix/web/zabbix.conf.php` | Frontend DB connection |
| Zabbix Agent 2 | `/etc/zabbix/zabbix_agent2.conf` | Agent configuration |
| MySQL | `/etc/mysql/my.cnf` or `/etc/mysql/mysql.conf.d/zabbix.cnf` | Database tuning |
| Grafana | `/etc/grafana/grafana.ini` | Grafana configuration |
| Nginx (Zabbix) | `/etc/nginx/sites-available/zabbix` | Web server config |
| Loki | `/etc/loki/local-config.yaml` | Log aggregation config |

## Appendix C: Useful Zabbix CLI Commands

```bash
# Check Zabbix server status
zabbix_server -R config_cache_reload    # Reload configuration cache
zabbix_server -R diaginfo               # Diagnostic information
zabbix_server -R ha_status              # HA cluster status
zabbix_server -R prof_enable            # Enable profiling

# Test agent connectivity
zabbix_get -s <host_ip> -k agent.ping   # Test passive agent
zabbix_get -s <host_ip> -k system.cpu.util  # Get CPU utilization

# Database maintenance
psql -U zabbix -c "SELECT * FROM pg_stat_activity WHERE datname='zabbix';"
psql -U zabbix -c "SELECT pg_size_pretty(pg_database_size('zabbix'));"

# Check Zabbix queue (items waiting for collection)
zabbix_server -R diaginfo | grep -A5 "queue"
```

---

> **Document Control**
> - **Version:** 1.0
> - **Status:** Production-Ready
> - **Review Date:** 2026-06-16
> - **Next Review:** 2026-09-16
