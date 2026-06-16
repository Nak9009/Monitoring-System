# Local Testing Guide: Docker Compose Monitoring Stack

This guide explains how to spin up, configure, and test the entire Zabbix 7.0 + Grafana + Loki + Uptime Kuma monitoring stack locally on your workstation using the provided Docker Compose configuration.

---

## 1. Prerequisites
Ensure you have the following installed on your local machine:
- **Docker Desktop** (macOS/Windows) or **Docker Engine + Docker Compose Plugin** (Linux).
- **openssl** (used for generating self-signed TLS certificates).
- **curl** (for testing API endpoints).

---

## 2. Quick-Start Setup Steps

Follow these steps to initialize and start the local environment:

### Step 1: Clone or Navigate to the Directory
Open your terminal and navigate to the `docker-compose` folder:
```bash
cd /Users/ratanakieng/.gemini/antigravity/scratch/monitoring-stack/docker-compose
```

### Step 2: Configure Environment Variables
Create your local `.env` configuration file from the template:
```bash
cp .env.example .env
```
Open `.env` in a text editor and customize the passwords. For a quick local test, you can set the passwords as follows:
```env
DB_PASSWORD=localtestpassword123
DB_ROOT_PASSWORD=localrootpassword123
GF_SECURITY_ADMIN_PASSWORD=localgrafanapassword123
```

### Step 3: Generate Self-Signed SSL Certificates
The Nginx container requires SSL certificates to serve Zabbix over HTTPS. Create the certificate directory and generate self-signed certs:
```bash
# Create certs directory
mkdir -p certs

# Generate self-signed certificate and private key (valid for 365 days)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key \
  -out certs/server.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=localhost"
```

### Step 4: Start the Stack
Run Docker Compose in the background:
```bash
docker compose up -d
```
This command downloads the required container images, initializes MySQL 8.0, imports the database schema, and starts all services.

---

## 3. Accessing the Local Services

Once the containers are running, you can access the Web consoles via the following URLs:

| Service | Protocol / URL | Default Credentials | Description |
| :--- | :--- | :--- | :--- |
| **Zabbix Web UI** | `https://localhost:8443` | `Admin` / `zabbix` | Central monitoring dashboard (HTTPS) |
| **Zabbix HTTP** | `http://localhost:8080` | `Admin` / `zabbix` | Unencrypted Web UI fallback |
| **Grafana** | `http://localhost:3000` | `admin` / (Your `.env` password) | Visual dashboard interface |
| **Uptime Kuma** | `http://localhost:3001` | *Create account on first load* | Synthetic checks and status pages |
| **Loki API** | `http://localhost:3100/ready` | N/A | Log aggregator health check |

---

## 4. Testing & Validation Scenarios

### Scenario A: Verify Database Connection and Tables
Verify that MySQL is running and Zabbix tables are populated successfully:
```bash
docker exec -it mon-mysql mysql -u zabbix -plocaltestpassword123 -D zabbix -e "SHOW TABLES LIKE 'users';"
```
*You should see the 'users' table listed, indicating the schema was successfully imported.*

### Scenario B: Verify Host Log Shipping (Loki + Promtail)
1. Open **Grafana** (`http://localhost:3000`) and log in.
2. Navigate to **Connections** -> **Data Sources** -> **Add new data source** -> Select **Loki**.
3. Set the URL to `http://loki:3100` and click **Save & Test**.
4. Go to **Explore**, select the **Loki** data source, and query logs (e.g. container logs or system logs):
   ```text
   {job="docker"}
   ```

### Scenario C: Run the Backup Script
Test the automated backup script to ensure it generates dump files successfully:
```bash
# Execute the backup script locally
sudo ./scripts/backup.sh
```
Verify that the backup output (.tar.gz and .sql.gz archives) has been generated under your backup target directory.

### Scenario D: Test Telegram Alerts
Configure your bot token and chat ID in the `.env` file, then trigger a test message:
```bash
./scripts/telegram-setup.sh
```

---

## 5. Stopping the Environment
To stop the environment and preserve your metrics data:
```bash
docker compose down
```
To stop the environment and completely wipe all stored data (including volumes):
```bash
docker compose down -v
```
