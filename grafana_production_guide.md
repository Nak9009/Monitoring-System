# Grafana 11 Production Operations & Ingestion Guide

This document provides complete instructions for configuring, operating, and securing Grafana 11 in a production environment. It covers data sources, dashboard layouts, custom alerting, security hardening (LDAP/OIDC), and high-availability (HA) database configurations.

---

## 1. Production Data Source Architecture

Grafana is connected to three primary data sources in this stack. For production scaling, we optimize their performance profiles.

```
┌────────────────────────────────────────────────────────┐
│                        GRAFANA                         │
└────────────────────────────────────────────────────────┘
     │                    │                     │
     ▼ (REST API)         ▼ (Direct SQL)        ▼ (HTTP)
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Zabbix API  │   │  MySQL DB    │   │   Loki API   │
│ (Metadata/   │   │ (High-Perf   │   │ (Logs/LogQL) │
│  Realtime)   │   │  History)    │   │              │
└──────────────┘   └──────────────┘   └──────────────┘
```

### 1.1 Zabbix API Integration (API Data Source)
*   **Purpose**: Gathers host inventory, trigger statuses, and real-time metric streams.
*   **Production Optimization**:
    *   **Cache TTL**: Set to `1h` (reduces load on Zabbix web servers by caching host lists).
    *   **Direct DB Connection**: Enabled pointing to `Zabbix-MySQL` (direct queries bypass PHP and fetch history metrics up to 10x faster).
    *   **Trends Read**: Set `trends: true` and `trendsFrom: "7d"` to query averaged trend tables for timeframes wider than 7 days instead of heavy history tables.

### 1.2 Loki (Log Source)
*   **Purpose**: Log aggregation and query analysis.
*   **Production Optimization**:
    *   **Max Lines Limit**: Capped at `5000` to prevent browser freezing during massive queries.
    *   **Derived Fields**: Configured to link container names to Zabbix Host IDs automatically, enabling one-click log-to-metric navigation.

---

## 2. Production Dashboard Layout Samples

To achieve a **DigitalOcean Insights** equivalent, organize your panels into logical rows with the following configurations.

### 2.1 Dashboard A: System Infrastructure (Linux Host)
*   **Variables**:
    *   `$Group`: Zabbix Host Group (Query: `*`)
    *   `$Host`: Zabbix Host (Query: `$Group.*`)
*   **Panel Row 1: Host Health Metrics**
    *   **Uptime**: Stat Panel (Metric: `system.uptime`, Format: `duration`)
    *   **Agent Ping**: Stat Panel (Metric: `agent.ping`, Mappings: `1 -> Up` (Green), `0 -> Down` (Red))
*   **Panel Row 2: CPU Insights**
    *   **CPU Utilization**: Time Series (Metrics: `system.cpu.util[,user]`, `system.cpu.util[,system]`, `system.cpu.util[,iowait]`)
    *   **Load Average**: Time Series (Metrics: `system.cpu.load[all,avg1]`, `system.cpu.load[all,avg5]`)
*   **Panel Row 3: Memory Insights**
    *   **Memory Usage**: Time Series (Metrics: Total, Available, Cached, and Buffers)
    *   **Memory Utilization**: Gauge (Expression: `((Total - Available) / Total) * 100%`)
*   **Panel Row 4: Disk Storage & I/O**
    *   **Disk Usage**: Bar Gauge (Metric: `vfs.fs.size[/,pfree]`, Thresholds: `>20% Green`, `10%-20% Orange`, `<10% Red`)
    *   **Disk Read/Write Latency**: Time Series (Metrics: `vfs.dev.read.await`, `vfs.dev.write.await`)
    *   **Disk IOPS**: Time Series (Metrics: `vfs.dev.read.rate`, `vfs.dev.write.rate`)
*   **Panel Row 5: Network Traffic**
    *   **Bandwidth Utilization**: Time Series (Metrics: `net.if.in[eth0]`, `net.if.out[eth0]`, Unit: `bytes/sec (IEC)`)

---

## 3. Production Alerting & Custom Telegram Notifications

Alerts can be managed and sent from either Zabbix or Grafana. While they both route notifications (e.g., to Telegram), they have different architectures and use cases.

### 3.1 Zabbix Alerts vs. Grafana Alerts: Architectural Comparison

| Feature | Zabbix Alerting (Backend Engine) | Grafana Alerting (Frontend Visualizer) |
| :--- | :--- | :--- |
| **Evaluation Method** | **Real-time** inside the Zabbix core daemon as metrics arrive. | **Periodic polling** (running database/API queries at intervals). |
| **Data Scope** | Limited to Zabbix metric database. | Can alert across any source (Zabbix, Loki logs, MySQL, etc.). |
| **Reliability** | **Extremely High**. Runs at the system daemon level; doesn't require UI or Web proxy. | Medium. Depends on Grafana service and API health. |
| **Performance Overhead** | Very low. Optimized C-daemon architecture. | High database/API query load if monitoring thousands of items. |
| **Actions** | Can trigger automatic shell commands/recovery scripts on hosts. | Read-only. Cannot execute commands. |
| **Message Quality** | Clean text/markdown logs. | Visually rich HTML, embedded charts, and action links. |

#### Production Best Practice
*   **Use Zabbix Alerting for**: Core system availability (ping failures, host downs), critical hardware resource exhaustion, and triggers requiring automated resolution scripts (e.g. restarting a service).
*   **Use Grafana Alerting for**: Log anomalies (queries on Loki), correlating metrics from multiple databases, and generating rich, visual reports to communication channels (Slack/Telegram).

### 3.2 Creating a Grafana Alert Rule
1. Navigate to **Alerts** -> **Alert rules** -> **Create rule**.
2. **Define Query**:
   * **Data Source**: `Zabbix`
   * **Query**: Group: `Virtual Machines`, Host: `+`, Item: `CPU utilization`
3. **Set Threshold**:
   * Set condition `Is Above` -> `80`.
4. **Configure Contact Point (Telegram)**:
   * Go to **Alerts** -> **Contact points** -> **Add contact point**.
   * **Integration**: `Telegram`.
   * **Bot Token**: `YourToken`
   * **Chat ID**: `YourChatID`

### 3.2 Premium Custom Telegram Alert Template
Paste the following template into your contact point's **Custom Message** field to format alerts with HTML tags, severity badges, and quick-links:

```html
{{ if eq .Status "firing" }}
🚨 <b>[FIRING] {{ .CommonLabels.alertname }}</b> 🚨

<b>Severity:</b> 🟠 Average
<b>Host:</b> 🖥️ <code>{{ .CommonLabels.host }}</code>
<b>Description:</b> {{ .CommonAnnotations.description }}
<b>Value:</b> 📈 {{ .CommonAnnotations.value }}%

🌐 <a href="http://your-grafana-url/d/linux-host">View Grafana Dashboard</a>
{{ else }}
✅ <b>[RESOLVED] {{ .CommonLabels.alertname }}</b> ✅

<b>Host:</b> 🖥️ <code>{{ .CommonLabels.host }}</code>
<b>Status:</b> Back to Normal.
{{ end }}
```

---

## 4. Security Hardening & SSO (LDAP & OAuth)

In production, do not manage users locally. Integrate Grafana with your Central Directory (LDAP / Active Directory) or OAuth provider.

### 4.1 Configuring LDAP / Active Directory
Create or edit `/etc/grafana/ldap.toml` (mounted via docker-compose config):

```toml
[[servers]]
host = "ldap.company.internal"
port = 636
use_ssl = true
start_tls = false
bind_dn = "cn=read-only-admin,dc=company,dc=internal"
bind_password = "SecureLDAPPassword"

search_filter = "(sAMAccountName=%s)"
search_base_dns = ["ou=Users,dc=company,dc=internal"]

[servers.group_mappings]
group_dn = "cn=sysops,ou=Groups,dc=company,dc=internal"
org_role = "Admin"

group_dn = "cn=developers,ou=Groups,dc=company,dc=internal"
org_role = "Editor"

group_dn = "cn=business_users,ou=Groups,dc=company,dc=internal"
org_role = "Viewer"
```

Then, enable it in your `.env` or `docker-compose.yml` environment:
```env
GF_AUTH_LDAP_ENABLED=true
GF_AUTH_LDAP_CONFIG_FILE=/etc/grafana/ldap.toml
```

### 4.2 Configuring Google OAuth / OpenID Connect (OIDC)
Add the following environment variables to your `.env` to enable Google Workspace Single Sign-On:

```env
GF_AUTH_GOOGLE_ENABLED=true
GF_AUTH_GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GF_AUTH_GOOGLE_CLIENT_SECRET=your_client_secret
GF_AUTH_GOOGLE_SCOPES=https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email
GF_AUTH_GOOGLE_AUTH_URL=https://accounts.google.com/o/oauth2/auth
GF_AUTH_GOOGLE_TOKEN_URL=https://oauth2.googleapis.com/token
GF_AUTH_GOOGLE_ALLOWED_DOMAINS=company.com
GF_AUTH_GOOGLE_ALLOW_SIGN_UP=true
```

---

## 5. High-Availability (HA) Database Migration

By default, Grafana stores its state (dashboards, users, alerts) inside an ephemeral SQLite database (`/var/lib/grafana/grafana.db`). **For production, you must migrate this to PostgreSQL or MySQL** so that you can scale Grafana horizontally without data loss.

### 5.1 Setting Up a Production MySQL State Store
1. Edit `docker-compose.yml` to inject the MySQL connection variables to your Grafana container:

```yaml
  grafana:
    image: grafana/grafana-oss:11.6.0
    environment:
      # Database connection parameters
      GF_DATABASE_TYPE: mysql
      GF_DATABASE_HOST: mysql:3306
      GF_DATABASE_NAME: grafana
      GF_DATABASE_USER: grafana
      GF_DATABASE_PASSWORD: ${DB_PASSWORD:?Set DB_PASSWORD in .env}
```

2. When Grafana restarts, it will automatically run schema migrations and populate the tables inside the target MySQL database. You can now safely run multiple Grafana containers behind a load balancer!
