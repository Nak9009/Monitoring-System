# VM Agent Deployment & Verification Guide (Ubuntu & Windows)

This document provides step-by-step instructions for deploying the Zabbix Agent 2 on Ubuntu and Windows test VMs and validating their communication with the High-Availability (HA) Monitoring Stack.

---

## 1. VM Sizing & Network Allocation

To perform testing, provision the following virtual machines and ensure they are on the same VLAN/subnet.

| VM Name | Role | OS | CPU | RAM | Disk | Assigned IP |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`mon-primary`** | HA Primary Server | Ubuntu 24.04 LTS | 8 vCPUs | 4 GB | 200 GB | `10.0.100.10` |
| **`mon-standby`** | HA Standby Server | Ubuntu 24.04 LTS | 8 vCPUs | 4 GB | 200 GB | `10.0.100.11` |
| **`test-ubuntu-vm`** | Agent Test Target | Ubuntu 22.04 / 24.04 LTS | 2 vCPUs | 2 GB | 40 GB | `10.0.100.20` |
| **`test-windows-vm`** | Agent Test Target | Windows Server / Win 10/11 | 2 vCPUs | 4 GB | 40 GB | `10.0.100.30` |

> [!NOTE]  
> All agents must point to the Keepalived Virtual IP (VIP) **`10.0.100.100`** rather than the individual physical IP of `mon-primary` or `mon-standby`.

---

## 2. Firewall Rules & Port Matrix

Before installing the agents, ensure firewalls are configured to allow communication.

```
                  Active Checks (Port 10051)
   ┌──────────────────────────────────────────────────────┐
   │                                                      ▼
┌──────────────┐                                  ┌──────────────┐
│ Monitored VM │                                  │  Zabbix VIP  │
│ (Ubuntu/Win) │                                  │ 10.0.100.100 │
└──────────────┘                                  └──────────────┘
   ▲                                                      │
   └──────────────────────────────────────────────────────┘
                 Passive Checks (Port 10050)
```

| Source | Destination | Port / Protocol | Direction | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Monitored VMs** | **`10.0.100.100`** | `10051 / TCP` | Outbound | Active checks & config retrieval |
| **`10.0.100.100`** | **Monitored VMs** | `10050 / TCP` | Inbound | Passive checks & poll requests |

### Applying Local Firewall Rules

#### On the Ubuntu Target VM:
```bash
sudo ufw allow 10050/tcp comment 'Zabbix Agent Passive'
sudo ufw allow out 10051/tcp comment 'Zabbix Server Active'
sudo ufw reload
```

#### On the Windows Target VM (PowerShell):
```powershell
New-NetFirewallRule -DisplayName "Zabbix Agent Passive" -Direction Inbound -LocalPort 10050 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Zabbix Server Active" -Direction Outbound -RemotePort 10051 -Protocol TCP -Action Allow
```

---

## 3. Ubuntu VM: Agent Installation & Setup

Follow these commands to install and configure the Zabbix Agent 2 on the Ubuntu VM.

### Step 1: Install Zabbix Repo and Packages
```bash
# Download and install the Zabbix repository configuration
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo apt update

# Install Agent 2 and its standard plugins
sudo apt install -y zabbix-agent2 zabbix-agent2-plugin-*
```

### Step 2: Generate PSK Key for Secure Connection
```bash
# Generate a random 64-character PSK hex key
openssl rand -hex 32 | sudo tee /etc/zabbix/zabbix_agent2.psk

# Set secure permissions
sudo chmod 440 /etc/zabbix/zabbix_agent2.psk
sudo chown root:zabbix /etc/zabbix/zabbix_agent2.psk
```
*Make a note of the generated key output; you will need to paste this into the Zabbix Web UI later.*

### Step 3: Configure the Agent
Edit the configuration file `/etc/zabbix/zabbix_agent2.conf`:
```ini
Server=10.0.100.100
ServerActive=10.0.100.100
Hostname=test-ubuntu-vm
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=monitoring-stack-psk
TLSPSKFile=/etc/zabbix/zabbix_agent2.psk
```

### Step 4: Start and Enable the Agent Service
```bash
sudo systemctl enable zabbix-agent2
sudo systemctl restart zabbix-agent2
```

---

## 4. Windows VM: Agent Installation & Setup

Follow these steps to deploy the Zabbix Agent 2 on the Windows VM.

### Step 1: Download & Silent Install
Download the official Zabbix Agent 2 MSI installer for Windows and run the following silent installation command in an Administrator Command Prompt or PowerShell:

```cmd
msiexec.exe /i zabbix_agent2-7.0.0-windows-amd64-openssl.msi /qn `
  SERVER=10.0.100.100 `
  SERVERACTIVE=10.0.100.100 `
  HOSTNAME=test-windows-vm `
  TLSCONNECT=psk `
  TLSACCEPT=psk `
  TLSPSKIDENTITY=monitoring-stack-psk `
  TLSPSKFILE="C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk"
```

### Step 2: Write PSK File
Generate or copy your 64-character PSK hex key and save it to the path specified:
*   **Path**: `C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk`

### Step 3: Start the Service
In PowerShell (as Administrator), ensure the service is set to automatic startup and restart it:
```powershell
Set-Service -Name "Zabbix Agent 2" -StartupType Automatic
Restart-Service -Name "Zabbix Agent 2"
```

---

## 5. Verification Scenarios

Run these tests to confirm that your target VMs are working properly with the monitoring infrastructure.

### Scenario A: Network Connectivity Check
Ensure the VMs and the server can communicate on designated ports.

*   **From Ubuntu/Windows VM to Zabbix Server**:
    ```bash
    # From Linux VM:
    nc -zv 10.0.100.100 10051
    
    # From Windows VM (PowerShell):
    Test-NetConnection -ComputerName 10.0.100.100 -Port 10051
    ```
*   **From Zabbix Server to VMs**:
    ```bash
    nc -zv 10.0.100.20 10050  # Test Ubuntu VM
    nc -zv 10.0.100.30 10050  # Test Windows VM
    ```

### Scenario B: Active Poll Check (`zabbix_get`)
From the Zabbix Server command line, verify you can pull system metrics directly using the PSK credentials:

```bash
# Verify Ubuntu VM
zabbix_get -s 10.0.100.20 -k agent.ping \
  --tls-connect=psk \
  --tls-psk-identity="monitoring-stack-psk" \
  --tls-psk-file=/etc/zabbix/zabbix_agent2.psk

# Verify Windows VM
zabbix_get -s 10.0.100.30 -k agent.ping \
  --tls-connect=psk \
  --tls-psk-identity="monitoring-stack-psk" \
  --tls-psk-file=/etc/zabbix/zabbix_agent2.psk
```
*Expected Output: `1`*

### Scenario C: Console Discovery & UI Metrics Ingestion
1.  Open your browser and log in to the **Zabbix Web UI** (`http://10.0.100.100/zabbix` or `http://localhost:8080` for local environment).
    *   **Default Username**: `Admin` *(case-sensitive)*
    *   **Default Password**: `zabbix`
2.  Go to **Configuration** -> **Hosts** -> click **Create host**.
3.  Fill in the host details:
    *   **Host name**: `test-ubuntu-vm` (or `test-windows-vm`). *Must exactly match the Hostname value configured in the agent config.*
    *   **Templates**: Select `Linux by Zabbix agent` or `Windows by Zabbix agent`.
    *   **Host groups**: Select or create a group (e.g., `Virtual Machines`).
    *   **Interfaces**: Click **Add** -> **Agent**, and enter the VM's static IP (`10.0.100.20` or `10.0.100.30`). Keep port as `10050`.
4.  Switch to the **Encryption** tab:
    *   **Connections to host**: Select `PSK`.
    *   **Connections from host**: Check `PSK`.
    *   **PSK identity**: `monitoring-stack-psk`.
    *   **PSK**: Paste the 64-character hex key string generated in Phase 3 or 4.
5.  Click **Add**.
6.  Wait 60 seconds. Confirm that the **ZBX** icon under the Availability column turns green.
7.  Go to **Monitoring** -> **Latest data**, filter by your host, and ensure system charts (CPU load, memory usage, swap, disk write speeds) are updating in real-time.

---

## 6. Troubleshooting Common Agent Issues

| Issue / Error | Likely Cause | Solution |
| :--- | :--- | :--- |
| **`Connection refused` or timeout on port 10050/10051** | Firewall blocking traffic or Agent Service is down. | 1. Check if the agent is running (`systemctl status zabbix-agent2`).<br>2. Run local UFW/Windows Firewall checks. |
| **`Active check configuration download ... TLS handshake failed`** | Encryption mismatched or PSK Identity strings differ. | Verify that the PSK hex key in the agent's `.psk` file exactly matches the PSK value entered in the Zabbix Web UI. |
| **`Cannot send list of active checks ... host not found`** | Hostname mismatch. | The `Hostname` parameter in `/etc/zabbix/zabbix_agent2.conf` must *exactly* match (case-sensitive) the **Host name** field configured in the Zabbix Web UI. |
| **`Connection from <IP> rejected, allowed hosts: ...`** | Wrong server IP listed in `Server` parameter. | Ensure `Server` and `ServerActive` in your agent configuration point to the Zabbix VIP `10.0.100.100`. |
