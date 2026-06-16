# Service Operations & Directory Guide

This document provides a detailed, easy-to-understand breakdown of every service running in the Enterprise Monitoring Stack, explaining what they do, how to access them, where their configuration files are located, and how to manage them.

---

## 1. Stack Architecture & Communication Flow

The stack is split into two virtual networks:
1.  **`monitoring-frontend`**: Exposed to users and administrators for dashboard access.
2.  **`monitoring-backend`**: Private internal network for databases, log streams, and daemon communications.

```
                      [ IT Operator / Web Browsers ]
                                    │
       ┌────────────────────────────┼────────────────────────────┐
       ▼ (Port 8443 / 8080)         ▼ (Port 3000)                ▼ (Port 3001)
┌──────────────┐             ┌──────────────┐             ┌──────────────┐
│Zabbix Web UI │             │ Grafana 11   │             │ Uptime Kuma  │
└──────┬───────┘             └──────┬───────┘             └──────────────┘
       │                            │ (Queries Logs & Metrics)
       │                            ▼
       │                     ┌──────────────┐
       │     ┌──────────────►│ Grafana Loki │◄──────────────┐
       │     │               └──────────────┘               │ (Ships Logs)
       ▼     ▼ (Stores Logs)                                │
┌──────────────┐                                     ┌──────────────┐
│Zabbix Server │                                     │   Promtail   │
└──────┬───────┘                                     └──────┬───────┘
       │ (Stores Metrics)                                   │
       ▼                                                    │ (Scrapes Logs)
┌──────────────┐                                            ▼
│ MySQL DB 8.0 │                                      [ Docker Host ]
└──────────────┘                                      [  System Logs  ]
```

---

## 2. Individual Service Reference

### 2.1 MySQL 8.0 Database (`mysql`)
*   **Purpose**: Stores all Zabbix configuration data (hosts, templates, users, items) and historical monitoring data.
*   **Access & Ports**:
    *   **Internal Network**: Port `3306` at `mysql` (IP: `172.20.1.10`)
    *   **External Access**: Port `3306` (Localhost)
*   **Default Database Details**:
    *   **DB Name**: `zabbix` (default)
    *   **DB User**: `zabbix`
*   **Configurations**:
    *   Tuned MySQL parameters file: [my.cnf](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/mysql/my.cnf)
*   **Common Commands**:
    ```bash
    # View database health
    docker exec -it mon-mysql mysqladmin ping -u zabbix -p
    
    # Enter the MySQL shell
    docker exec -it mon-mysql mysql -u zabbix -p zabbix
    ```

---

### 2.2 Zabbix Server 7.0 LTS (`zabbix-server`)
*   **Purpose**: The processing core. It receives metrics from agents, evaluates triggers/alert rules, and persists them to the database.
*   **Access & Ports**:
    *   **Internal Network**: Port `10051` at `zabbix-server` (IP: `172.20.1.11`)
    *   **External Access**: Port `10051` (Localhost)
*   **Configurations**:
    *   Config variables located in [docker-compose.yml](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/docker-compose.yml#L87-L146)
    *   Custom extra parameters: [zabbix_server_extra.conf](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/zabbix/zabbix_server_extra.conf)
*   **Common Commands**:
    ```bash
    # Check internal execution logs
    docker compose logs -f zabbix-server
    
    # Force run configuration sync
    docker exec -it mon-zabbix-server zabbix_server -R config_cache_reload
    ```

---

### 2.3 Zabbix Web Frontend (`zabbix-frontend`)
*   **Purpose**: Web console GUI for Zabbix administration, dashboard building, and alert acknowledgment.
*   **Access & Ports**:
    *   **Secure (HTTPS)**: `https://localhost:8443` *(Recommended)*
    *   **Standard (HTTP)**: `http://localhost:8080`
    *   **Credentials**: `Admin` / `zabbix`
*   **Configurations**:
    *   Nginx Web server SSL server config: [zabbix-ssl.conf](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/nginx/zabbix-ssl.conf)
*   **Common Commands**:
    ```bash
    # View web access & PHP error logs
    docker compose logs -f zabbix-frontend
    ```

---

### 2.4 Zabbix Agent 2 (`zabbix-agent`)
*   **Purpose**: Lightweight collector running on the Docker host itself. It monitors CPU, RAM, Disk, and containers, shipping metrics to Zabbix Server.
*   **Access & Ports**:
    *   **Internal Network**: Port `10050` at `zabbix-agent` (IP: `172.20.1.13`)
*   **Common Commands**:
    ```bash
    # Test if agent can fetch local OS information
    docker exec -it mon-zabbix-agent zabbix_agent2 -t system.cpu.load
    ```

---

### 2.5 Zabbix SNMP Trap Receiver (`zabbix-snmptraps`)
*   **Purpose**: Listens for SNMP Trap alert packets sent from switches, routers, and physical firewalls, transforming them into events Zabbix can ingest.
*   **Access & Ports**:
    *   **External Listen**: Port `162 / UDP`
*   **Common Commands**:
    ```bash
    # View incoming trap streams
    docker compose logs -f zabbix-snmptraps
    ```

---

### 2.6 Grafana 11 OSS (`grafana`)
*   **Purpose**: Visually stunning dashboarding suite. Ingests data from Zabbix (via plugin) and Loki to display beautiful, unified metrics & logs.
*   **Access & Ports**:
    *   **Web Portal**: `http://localhost:3000`
    *   **Credentials**: Defined in your `.env` configuration (`GF_SECURITY_ADMIN_PASSWORD`).
*   **Configurations**:
    *   Automated data source provisioning: [provisioning/datasources](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/grafana/provisioning/datasources/)
    *   Automated dashboard provisioning: [provisioning/dashboards](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/grafana/provisioning/dashboards/)
*   **Common Commands**:
    ```bash
    # Check if Grafana is healthy
    curl -f http://localhost:3000/api/health
    ```

---

### 2.7 Grafana Loki (`loki`)
*   **Purpose**: The central log storage database. It indexes and compresses system logs, application logs, and Docker container output streams.
*   **Access & Ports**:
    *   **Internal Network**: Port `3100` at `loki` (IP: `172.20.1.30`)
*   **Configurations**:
    *   Loki database parameters: [loki-config.yml](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/loki/loki-config.yml)
*   **Common Commands**:
    ```bash
    # Check if Loki storage is ready to receive logs
    curl http://localhost:3100/ready
    ```

---

### 2.8 Promtail Log Shipper (`promtail`)
*   **Purpose**: Scrapes local system logs (`/var/log/*`) and Docker daemon container files, automatically formatting them and shipping them to Loki.
*   **Configurations**:
    *   Scrape targets and pipelines: [promtail-config.yml](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/configs/promtail/promtail-config.yml)
*   **Common Commands**:
    ```bash
    # View log shipping pipeline status
    docker compose logs -f promtail
    ```

---

### 2.9 Uptime Kuma (`uptime-kuma`)
*   **Purpose**: Lightweight synthetic monitoring. Performs simple external ping, HTTP status code checks, and DNS resolution checks. Ideal for generating public Status Pages.
*   **Access & Ports**:
    *   **Web Portal**: `http://localhost:3001`
    *   **Credentials**: Set up your admin account on the first Web UI page load.
*   **Common Commands**:
    ```bash
    # Verify status
    docker compose logs -f uptime-kuma
    ```

---

## 3. Docker Compose Operational Cheat Sheet

Use these quick terminal commands inside the `docker-compose` folder to manage the entire stack.

### Start the Stack
```bash
docker compose up -d
```

### Stop the Stack (Preserve Data)
```bash
docker compose down
```

### Stop and Wipe All Data Volumes (Hard Reset)
```bash
docker compose down -v
```

### Check Running Services & Health Status
```bash
docker compose ps
```

### View Live Combined Logs
```bash
docker compose logs -f --tail=100
```

### View Live Logs of a Specific Service
```bash
# Example: view only mysql logs
docker compose logs -f mysql
```

### Restart a Specific Service
```bash
# Example: restart only Grafana
docker compose restart grafana
```
