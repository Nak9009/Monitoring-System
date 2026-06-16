# Zabbix Web UI Operation & Management Guide

This document serves as the comprehensive user and administrator guide for operating the Zabbix 7.0 LTS Web Interface deployed within this monitoring infrastructure.

---

## 1. Access & Security Settings

### 1.1 Interface Access Points
*   **Local Docker Development**:
    *   Secure (HTTPS): `https://localhost:8443`
    *   Standard (HTTP): `http://localhost:8080`
*   **Production Cluster (HA VIP)**:
    *   Standard Entry: `http://10.0.100.100/zabbix` (or `https://10.0.100.100/zabbix` depending on SSL Offloading/Nginx setup)

### 1.2 Default Credentials & Initialization
*   **Default Username**: `Admin` *(Case-sensitive)*
*   **Default Password**: `zabbix`

> [!WARNING]  
> Change the default admin password immediately upon first login to prevent unauthorized access.

### 1.3 How to Change Administrator Password
1.  Log in as the `Admin` user.
2.  In the left side panel, navigate to **Users** -> **Users**.
3.  Click on the username **Admin** in the list.
4.  Click the **Change password** button.
5.  Type in the new secure password and click **Update**.

---

## 2. Navigating the Zabbix 7.0 UI Layout

Zabbix 7.0 features a left-hand collapsible navigation menu. Key sections are:

*   **Monitoring**: Real-time status screens.
    *   *Dashboard*: Custom widgets, global health maps, and network topology.
    *   *Problems*: Current active triggers/alerts.
    *   *Hosts*: Real-time overview of monitored targets, their interfaces, and statuses.
    *   *Latest data*: Metric values currently being collected (CPU, memory, disk, etc.).
*   **Services**: SLA calculations and business service trees (monitoring uptime percentage).
*   **Inventory**: Hardware, software, and MAC addresses gathered automatically from monitored systems.
*   **Reports**: System diagnostics, SLA reports, and availability percentages.
*   **Data collection**: Configurations for targets.
    *   *Templates*: Base monitor rules applied to hosts.
    *   *Host groups*: Logical containers for managing permissions and bulk actions.
    *   *Hosts*: Creating and editing monitored endpoints.
*   **Alerts**: Media type setup (Telegram, Email, Slack) and automated actions.
*   **Administration**: Global configuration settings, user accounts, authentication (LDAP/SAML), and system health.

---

## 3. Host Lifecycle & Management

### 3.1 Adding a Monitored Host (Agent-Based)
To monitor a new server (Ubuntu/Windows) via Zabbix Agent 2:

1.  Navigate to **Data collection** -> **Hosts**.
2.  Click **Create host** in the upper-right corner.
3.  Under the **Host** tab:
    *   **Host name**: Enter the unique system hostname. *This must match the `Hostname` parameter in the agent configuration file exactly.*
    *   **Templates**: Select `Linux by Zabbix agent` or `Windows by Zabbix agent`.
    *   **Host groups**: Assign to a group (e.g., `Virtual Machines`, `Database Servers`).
    *   **Interfaces**: Click **Add** -> **Agent**. Input the host's IP address (e.g., `10.0.100.20`) and keep port `10050`.
4.  Under the **Encryption** tab (for PSK security):
    *   **Connections to host**: Select `PSK`.
    *   **Connections from host**: Check `PSK`.
    *   **PSK identity**: Set to a standard name, e.g., `monitoring-stack-psk`.
    *   **PSK**: Paste the 64-character hex key string generated for the host (as detailed in [vm_testing_guide.md](file:///Users/ratanakieng/labs/Monitoring-System/vm_testing_guide.md)).
5.  Click **Add**.

### 3.2 Checking Host Availability
*   **Green (ZBX)**: Agent is communicating successfully.
*   **Red (ZBX)**: Connection failed. Hover over the red ZBX indicator to read the exact error message (e.g., `Timeout was reached`, `Connection refused`).

---

## 4. Visualizing Metrics & Latest Data

### 4.1 Accessing Metric Streams
To inspect real-time values collected from any system:

1.  Go to **Monitoring** -> **Latest data**.
2.  Use the filter bar to select your **Host groups** or specific **Hosts**.
3.  Click **Apply**.
4.  Locate the specific metric (e.g., `CPU utilization` or `Available memory`).
5.  Click **Graph** on the right side of the row to display a interactive timeseries chart.
6.  Click **History** to view the raw timestamped values.

> [!TIP]  
> In Latest Data, you can select multiple checkboxes next to different metrics and click **Display graph** at the bottom of the page to overlay multiple metrics on a single graph.

---

## 5. Alerts & Problem Lifecycle

### 5.1 Understanding Severity Levels
Zabbix alerts (Triggers) are classified into six severity levels:
*   ⚪ **Not classified**: Informational markers.
*   🔵 **Information**: Low priority, non-actionable changes (e.g., system time changed).
*   🟡 **Warning**: Potential issues, should be checked soon (e.g., disk space > 80%).
*   🟠 **Average**: High resource usage or performance degradation (e.g., high CPU load).
*   🔴 **High**: Crucial service failure or network degradation (e.g., MySQL service down).
*   🟤 **Disaster**: Complete node or infrastructure failure (e.g., host unreachable).

### 5.2 Acknowledging and Closing Problems
When an alert triggers, it is shown in **Monitoring** -> **Problems**.

1.  Locate the active problem.
2.  Click the **No** under the **Ack** (Acknowledge) column.
3.  In the pop-up window:
    *   Check **Acknowledge** to let team members know you are investigating.
    *   Add a comment/message detailing the issue or fix.
    *   (Optional) Change the severity of the alert if it is more or less critical.
    *   Check **Close problem** (if manual closing is allowed on that trigger template).
4.  Click **Update**.

---

## 6. Configuring Notifications & Integrations

To automatically send alerts to administrators via Email or Telegram Webhooks:

### 6.1 Creating a Media Type (e.g., Telegram Bot)
1.  Go to **Alerts** -> **Media types**.
2.  Select **Telegram** from the list.
3.  Provide the configuration parameters:
    *   **Token**: Your Telegram Bot token API (generated by `@BotFather`).
4.  Click **Update**.

### 6.2 Assigning Media to User Accounts
1.  Go to **Users** -> **Users**.
2.  Click on the user (e.g., **Admin** or a developer account).
3.  Switch to the **Media** tab.
4.  Click **Add**:
    *   **Type**: Select `Telegram`.
    *   **Send to**: Enter your Telegram Personal Chat ID or Group Chat ID.
    *   **When active**: Define hours/days (default: `1-7,00:00-24:00` for 24/7 alerts).
    *   **Use severity**: Check the severity levels that should trigger notifications.
5.  Click **Add**, then click **Update** on the main profile page.

### 6.3 Activating Alert Actions
1.  Go to **Alerts** -> **Actions** -> **Trigger actions**.
2.  Ensure that the action **Report problems to Zabbix administrators** is set to **Enabled**.
3.  *Any problem matching the trigger rules will now automatically generate and dispatch an alert to your users.*

---

## 7. Creating Maintenance Windows

To prevent alert storms during scheduled software updates, server reboots, or database tuning:

1.  Go to **Alerts** -> **Maintenance periods**.
2.  Click **Create maintenance period** in the upper-right corner.
3.  Under the **Maintenance** tab:
    *   **Name**: Enter a descriptive name (e.g., `Weekly Database Backup Patch`).
    *   **Maintenance type**:
        *   `With data collection`: Gathers metrics, but suppresses alert notifications.
        *   `No data collection`: Stops polling metrics entirely during the period.
4.  Under the **Periods** tab, click **Add**:
    *   Define the start date, time, and duration (e.g., every Sunday from 01:00 to 03:00).
5.  Under the **Hosts and groups** tab:
    *   Select the target **Host groups** or specific **Hosts** that will be undergoing maintenance.
6.  Click **Add**.

---

## 8. User Management & Permissions

### 8.1 User Roles
Configure authorization scopes under **Users** -> **User roles**:
*   **User Role**: Access limited to Monitoring dashboard; cannot modify configuration settings.
*   **Admin Role**: Full control over host creation, template changes, and trigger setups. Cannot modify global settings or system configurations.
*   **Super Admin Role**: Unrestricted root access (e.g., default `Admin` user).

### 8.2 User Groups and Permission Scopes
Permissions in Zabbix are assigned to **User Groups** and mapped against **Host Groups** (permissions cannot be set on individual hosts directly).

1.  Go to **Users** -> **User groups**.
2.  Click **Create user group**.
3.  Give it a name (e.g., `Linux System Admins`).
4.  Under the **Permissions** tab:
    *   Select the target Host Group (e.g., `Virtual Machines`).
    *   Select permission access: `Read-write` or `Read-only`.
5.  Under the **Users** tab:
    *   Add user accounts to the group.
6.  Click **Add**.
