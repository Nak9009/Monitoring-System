# Zabbix Agent 2 Installation Guide (Simulated SSH VM Container)

This guide walks you through SSH-ing into the simulated target VM container (`test-ssh-vm`), installing Zabbix Agent 2, configuring secure Pre-Shared Key (PSK) encryption, and linking it to your Zabbix server stack.

---

## 1. Connecting to the Simulated VM via SSH

The `test-ssh-vm` container is configured as a standard Ubuntu target with an active SSH server listening on port `22` (mapped to port `2222` on your local host).

Connect to the container from your workstation's terminal:
```bash
ssh testuser@localhost -p 2222
```
*   **Password**: `testpassword`
*   **Sudo Password**: `testpassword` (the user has full `sudo` privileges)

> [!NOTE]  
> If your SSH connection fails due to a "Host key verification failed" error (caused by changes to localhost ports in previous tests), clear your local known hosts entry:
> ```bash
> ssh-keygen -R "[localhost]:2222"
> ```

---

## 2. Installing Zabbix Agent 2

Once connected inside the `test-ssh-vm`, install Zabbix Agent 2 using the official Zabbix repository:

### Step 1: Add the Zabbix Official Repository
```bash
# Download Zabbix Release package for Ubuntu 24.04 LTS
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb

# Install the repository configuration
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb

# Update apt cache
sudo apt update
```

### Step 2: Install the Agent & Plugins
```bash
sudo apt install -y zabbix-agent2 zabbix-agent2-plugin-*
```

---

## 3. Configuring PSK Encryption (Secure Communication)

Zabbix Agent 2 supports TLS-PSK (Pre-Shared Key) encryption.

### Step 1: Generate a random 64-character PSK hex key
```bash
# Generate and save key to agent secret path
openssl rand -hex 32 | sudo tee /etc/zabbix/zabbix_agent2.psk

# Secure file permissions (readable by root and zabbix group only)
sudo chmod 400 /etc/zabbix/zabbix_agent2.psk
sudo chown root:zabbix /etc/zabbix/zabbix_agent2.psk
```

### Step 2: Copy the generated PSK
Display the key so you can copy it for the Zabbix Web UI later:
```bash
cat /etc/zabbix/zabbix_agent2.psk
```
*(Example Output: `b87b702951f267980cd56ee22245b08c69197c36a6e9a89b93613a2a107849e8`)*

---

## 4. Configuring Zabbix Agent 2

Edit the agent configuration file:
```bash
sudo nano /etc/zabbix/zabbix_agent2.conf
```

Find and update the following configuration directives (or replace the file contents):
```ini
# Address of the Zabbix Server in the Docker network
Server=zabbix-server
ServerActive=zabbix-server

# The unique hostname of this machine (must match Zabbix Frontend UI host creation)
Hostname=test-ssh-vm

# Enable TLS-PSK authentication
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=monitoring-stack-psk
TLSPSKFile=/etc/zabbix/zabbix_agent2.psk
```

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

## 5. Starting the Agent

Ensure the agent service starts up and is enabled at system boot:
```bash
# Start and enable the service
sudo systemctl enable --now zabbix-agent2

# Check status to ensure it is running successfully
sudo systemctl status zabbix-agent2
```

---

## 6. Registering the VM in the Zabbix Web UI

1.  Open your browser and navigate to the **Zabbix Web UI** at `https://localhost:8443` (or `http://localhost:8080`).
    *   **Login**: `Admin` / `zabbix`
2.  Go to **Data collection** ➔ **Hosts** and click **Create host** (top-right).
3.  Configure the host:
    *   **Host name**: `test-ssh-vm` *(must match Hostname in agent config)*
    *   **Templates**: Select `Linux by Zabbix agent`
    *   **Host groups**: Select `Virtual Machines` (or create one)
    *   **Interfaces**: Click **Add** ➔ **Agent**. 
        *   Change **Connect to** to `DNS name`
        *   Set **DNS name** to `test-ssh-vm` *(resolves to container IP inside docker)*
        *   Keep port as `10050`
4.  Navigate to the **Encryption** tab:
    *   **Connections to host**: Select `PSK`
    *   **Connections from host**: Check `PSK`
    *   **PSK identity**: `monitoring-stack-psk`
    *   **PSK**: Paste the 64-character hex key string you copied in Section 3.
5.  Click **Add**.
6.  Wait 30-60 seconds. The availability indicator **ZBX** will turn **green**, indicating metrics are successfully streaming.
7.  Check live metrics by clicking **Monitoring** ➔ **Latest data** and filtering by `test-ssh-vm`.
