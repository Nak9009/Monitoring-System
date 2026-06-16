# System Design Architecture Diagrams

This document contains visual representations of the enterprise monitoring stack design using Mermaid.

---

## 1. High-Availability (HA) Network Architecture

This diagram shows the network setup, VLAN segmentations, and how Keepalived manages the Virtual IP (VIP) failover between `mon-primary` and `mon-standby`.

```mermaid
graph TB
    subgraph ClientAccess["Admin / Operations VLAN"]
        operator["IT Operator / Dashboard Viewer"]
    end

    subgraph MonitoringVLAN["Monitoring VLAN (10.0.100.0/24)"]
        VIP["Virtual IP (VIP)<br>10.0.100.100"]
        
        subgraph PrimaryNode["mon-primary (10.0.100.10)"]
            MasterKeepalived["Keepalived (MASTER)"]
            ZabbixServer1["Zabbix Server 7.0"]
            ZabbixFrontend1["Zabbix Web UI"]
            MySQL1[(MySQL 8.0 <br>Active)]
            Grafana["Grafana 11"]
            Loki["Loki Log DB"]
            UptimeKuma["Uptime Kuma"]
        end

        subgraph StandbyNode["mon-standby (10.0.100.11)"]
            BackupKeepalived["Keepalived (BACKUP)"]
            ZabbixServer2["Zabbix Server (Standby)"]
            ZabbixFrontend2["Zabbix Web UI (Standby)"]
            MySQL2[(MySQL 8.0 <br>Replica)]
        end
    end

    subgraph MonitoredSubnets["Monitored subnets (VLAN 10, 20, 30)"]
        LinuxHost["Linux Guest VMs<br>(Zabbix Agent 2 + Promtail)"]
        WinHost["Windows Guest VMs<br>(Zabbix Agent 2)"]
        NetDevices["Network Sw/Rt/Fw<br>(SNMP v2c/v3)"]
        Hypervisors["ESXi / Proxmox Hosts<br>(Hypervisor API)"]
    end

    subgraph Alerts["Alert Channels"]
        Telegram["Telegram Bot API"]
        Email["SMTP Relay"]
    end

    %% Client Routing
    operator -->|HTTPS:3000 / 8443| VIP
    VIP -.->|Binds to active master| PrimaryNode
    VIP -.->|Failover target| StandbyNode

    %% Replication
    MySQL1 ===>|MySQL Replication:3306| MySQL2

    %% Agent Data Flow
    LinuxHost -->|Active Checks:10051| VIP
    VIP -->|Passive Checks:10050| LinuxHost
    
    WinHost -->|Active Checks:10051| VIP
    VIP -->|Passive Checks:10050| WinHost

    VIP -->|SNMP Get/Walk:161/udp| NetDevices
    NetDevices -->|SNMP Traps:162/udp| VIP

    VIP -->|HTTPS API:443| Hypervisors

    %% External Alerts
    ZabbixServer1 -->|Webhook API| Telegram
    ZabbixServer1 -->|SMTP:587| Email
```

---

## 2. End-to-End Log & Metric Data Flow

This flowchart traces metrics from monitored systems through the ingestion components and database to the visualization layer.

```mermaid
flowchart LR
    subgraph MonitoredVM["Monitored Node"]
        app["Applications<br>(Laravel / Node.js)"]
        system["OS Resource Usage"]
        logs["/var/log/* & Container Logs"]
    end

    subgraph Ingestion["Ingestion Layer"]
        Agent["Zabbix Agent 2"]
        Promtail["Promtail Log Shipper"]
    end

    subgraph Storage["Storage & Core Engines"]
        ZServer["Zabbix Server 7.0"]
        DB[(MySQL 8.0)]
        LokiDB[(Grafana Loki Log DB)]
    end

    subgraph Viz["Visualization & Alerting"]
        GrafanaUI["Grafana 11 Dashboard"]
        ZabbixUI["Zabbix Web UI"]
        TelegramAlert["Telegram Alerts"]
    end

    %% Data flow mapping
    system -->|OS Metrics| Agent
    app -->|Custom plugins| Agent
    logs -->|Scrapes file/socket| Promtail

    Agent -->|Metrics:10051| ZServer
    Promtail -->|JSON streams:3100| LokiDB

    ZServer -->|Store history| DB
    ZServer -->|Trigger actions| TelegramAlert

    DB --->|Metrics source| GrafanaUI
    LokiDB --->|Logs source| GrafanaUI
    DB --->|UI queries| ZabbixUI
```
