# Step-by-Step Walkthrough: Adding a Host, Creating a Trigger, & Simulating an Alert

This document provides a concrete, end-to-end sample tutorial on using the Zabbix Web UI. You will learn how to add a target VM (`web-server-prod`), configure a custom CPU warning trigger, simulate high CPU load on the VM, and verify the resulting alert.

---

## Tutorial Objective
*   **Target VM**: `test-ubuntu-vm`
    *   *Real VM Option*: IP `10.0.100.20`
    *   *Docker Sandbox Option*: DNS name `test-ubuntu-vm` (IP `172.20.1.50`)
*   **Goal**: Monitor the VM, create an alert trigger that fires when CPU utilization exceeds **80%**, simulate a high CPU load to fire the alert, and acknowledge/clear it in the dashboard.

---

## Prerequisites: How to Get or Generate the PSK Key
Before adding the host to the UI, you need the 64-character PSK hex key. 

*   **Option 1: Read the existing key from the VM / Sandbox**
    *   *On Ubuntu VM*: Run `sudo cat /etc/zabbix/zabbix_agent2.psk`
    *   *On Docker Sandbox*: The key is set to: `85106eb436861adac326c71f032e9b9092502c1239c9a89b93613c2d107836d8`
    *   *On Windows VM*: Run `Get-Content "C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk"` in PowerShell.
*   **Option 2: Generate a new key from scratch**
    *   *On Linux/macOS*: Run `openssl rand -hex 32`
    *   *On Windows (PowerShell)*:
        ```powershell
        $bytes = New-Object Byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        ($bytes | ForEach-Object { "{0:x2}" -f $_ }) -join ""
        ```

---

## Step 1: Add the Host in Zabbix Web UI

1.  Log in to the Zabbix Web UI (`http://localhost:8080` or `https://localhost:8443`) using:
    *   **Username**: `Admin`
    *   **Password**: `zabbix`
2.  Navigate to **Data collection** -> **Hosts** and click the blue **Create host** button in the top right.
3.  Fill in the **Host** tab:
    *   **Host name**: `test-ubuntu-vm` *(Must match the `Hostname` parameter in the agent config)*
    *   **Templates**: Search and select `Linux by Zabbix agent`.
    *   **Host groups**: Type and select `Virtual Machines`.
    *   **Interfaces**: Click **Add** -> select **Agent**:
        *   **IP address**: `10.0.100.20` *(or DNS name `test-ubuntu-vm` if using the Docker Sandbox)*
        *   **Port**: `10050`
4.  Fill in the **Encryption** tab (for PSK):
    *   **Connections to host**: Select `PSK`.
    *   **Connections from host**: Check `PSK`.
    *   **PSK identity**: `monitoring-stack-psk`
    *   **PSK**: Paste your 64-character hex key (use `85106eb436861adac326c71f032e9b9092502c1239c9a89b93613c2d107836d8` if using the Docker Sandbox).
5.  Click the blue **Add** button.
6.  *Wait ~60 seconds.* Verify that the **ZBX** availability indicator icon in the Hosts table turns **green**.

---

## Step 2: Create a Custom CPU Alert Trigger

Although the standard template already alerts when CPU is extremely high, we will create a custom host-specific alert trigger for testing.

1.  Go to **Data collection** -> **Hosts**.
2.  Locate your newly added host `test-ubuntu-vm` and click on **Triggers** in its row.
3.  Click **Create trigger** in the top-right corner.
4.  Configure the Trigger:
    *   **Name**: `High CPU Load Detected on test-ubuntu-vm`
    *   **Severity**: Select 🟠 **Average**.
    *   **Expression**: Click **Add** to build the formula:
        *   *Item*: Click **Select** -> choose `CPU utilization`.
        *   *Function*: Select `last()` (most recent value).
        *   *Result*: Select `>` (greater than) and enter:
            *   **`5`** (if using the **Docker Sandbox** - since the container cannot stress your whole host machine).
            *   **`80`** (if using a **Real VM**).
        *   Click **Insert**. The expression should read:
            ```text
            last(/test-ubuntu-vm/system.cpu.util) > 5
            ```
    *   **Description**: `Trigger fires when CPU utilization exceeds threshold.`
5.  Click **Add**.

---

## Step 3: Simulate High CPU Load on the Target VM

Select the option below that matches your environment:

### Option A: If using the Docker Sandbox Container
Because the Zabbix agent in the container reads the host's `/proc/stat` to calculate CPU utilization, a single-threaded loop inside a CPU-limited container will only consume a tiny fraction of the total CPU on multi-core host machines (for instance, on a 12-core host, a single loop capped at `0.5` CPUs is only `0.5 / 12 = 4.16%` CPU utilization), which might not reliably cross the `> 5` threshold.

To resolve this, we have increased the `test-ubuntu-vm` container's CPU limit to `3.0` in [docker-compose.yml](file:///Users/ratanakieng/labs/Monitoring-System/docker-compose/docker-compose.yml), and we will spawn multiple parallel loops to generate sufficient CPU load:

1.  **Start the CPU load generator**:
    Run 3 parallel CPU-heavy loops in the background inside the container and use `wait` to keep the session alive:
    ```bash
    docker exec -d test-ubuntu-vm sh -c "while true; do true; done & while true; do true; done & while true; do true; done & wait"
    ```
2.  **Verify**: Check the Zabbix Web UI (**Monitoring** -> **Latest data** or the Dashboard). The trigger will fire and turn the dashboard red.
3.  **To stop the CPU load**:
    Simply restart the container to clear the background loops:
    ```bash
    docker compose restart test-ubuntu-vm
    ```

---

### Option B: If using a Real VM
1.  **SSH into the VM**:
    ```bash
    ssh username@10.0.100.20
    ```
2.  **Install the CPU stress tool**:
    ```bash
    sudo apt update && sudo apt install -y stress
    ```
3.  **Launch the CPU stress test**:
    ```bash
    # Run a CPU stress test on 4 cores for 5 minutes (300 seconds)
    stress --cpu 4 --timeout 300
    ```

---

## Step 4: Verify the Alert in the Zabbix Web UI

With the stress test running, watch the alert trigger fire in real-time.

1.  **View CPU utilization climb**:
    *   Go to **Monitoring** -> **Latest data**.
    *   Filter by Host: `test-ubuntu-vm`.
    *   Locate the `CPU utilization` row and click **Graph**. You should see the chart line climb above 80%.
2.  **Verify the Problem alert on Dashboard**:
    *   Go to **Monitoring** -> **Dashboard**.
    *   In the **Problems** widget, you will see a new active problem:
        *   **Severity**: 🟠 `Average`
        *   **Problem**: `High CPU Load Detected (Over 80%) on test-ubuntu-vm`
        *   **Status**: `PROBLEM`
3.  **Check Alerts / Actions logs**:
    *   Go to **Reports** -> **Action log**.
    *   Verify that an automated email or Telegram notification was successfully sent.

---

## Step 5: Acknowledge and Resolve the Alert

1.  **Acknowledge the Problem (Mark as Investigating)**:
    *   In the **Problems** table, click on the **No** under the **Ack** column.
    *   In the pop-up, enter: `Investigating high CPU utilization. Running stress tests.`
    *   Check **Acknowledge** and click **Update**.
    *   *The status indicator will show that the issue is acknowledged.*
2.  **Stop the CPU Load**:
    *   Go back to your SSH terminal. The `stress` command will exit automatically after 300 seconds, or you can terminate it early by pressing `Ctrl + C`.
3.  **Watch the Alert Auto-Resolve**:
    *   Once the CPU load returns to normal (< 80%), Zabbix will evaluate the expression `last() > 80` as false.
    *   The problem status changes from `PROBLEM` to `RESOLVED` and disappears from the active Problems widget.

---

## Step 6: Monitoring Memory (RAM) & Disk Space (HDD)

Zabbix monitors system memory and disk space using specialized item keys. Below is how to locate these metrics, create triggers for them, and safely simulate alerts.

### 1. Locating the Metrics in the Web UI
1. Go to **Monitoring** -> **Latest data**.
2. Filter by Host: `test-ubuntu-vm` and click **Apply**.
3. Search for:
   * **Memory**: `Available memory` (Key: `vm.memory.size[available]`)
   * **Disk**: `Space on /: Free` (Key: `vfs.fs.size[/,free]`)
4. Click **Graph** in the row of either metric to see history.

---

### 2. Setting Up & Simulating a Memory (RAM) Alert
Instead of consuming gigabytes of real RAM on your machine (which can crash your system), we simulate the alert by setting a threshold slightly above your current free memory:

1. Look at your current **Available memory** in the **Latest data** screen (for example: `5.2 GB`).
2. Go to **Data collection** -> **Hosts** -> click **Triggers** in the `test-ubuntu-vm` row.
3. Click **Create trigger** in the top right:
   * **Name**: `Low Free Memory Warning on test-ubuntu-vm`
   * **Severity**: 🟡 **Warning**
   * **Expression**: Click **Add**:
     * *Item*: Select `Available memory`
     * *Function*: `last()`
     * *Result*: Select `<` and enter a value slightly **higher** than your current free memory (e.g., if you have `5.2G` free, enter **`5.5G`** or **`6G`** to force the alert to trigger).
     * The expression will look like:
       ```text
       last(/test-ubuntu-vm/vm.memory.size[available]) < 5.5G
       ```
4. Click **Add**. 
5. Within 60 seconds, Zabbix will poll the memory, evaluate the expression, fire a **Warning** alert on the dashboard, and send a notification to your Telegram bot.
6. **To Resolve**: Edit the trigger and set the threshold back to a standard production value (e.g., `< 500M` or `< 1G`).

---

### 3. Setting Up & Simulating a Disk Space (HDD) Alert
Similarly, we trigger a disk alert safely by adjusting the trigger threshold to match your current free storage:

1. Look at your current **Free disk space on /: Free** in the **Latest data** screen (for example: `940 GB`).
2. Go to **Data collection** -> **Hosts** -> click **Triggers** in the `test-ubuntu-vm` row.
3. Click **Create trigger**:
   * **Name**: `Low Free Disk Space on test-ubuntu-vm`
   * **Severity**: 🟠 **Average**
   * **Expression**: Click **Add**:
     * *Item*: Select `Space on /: Free`
     * *Function*: `last()`
     * *Result*: Select `<` and enter a value slightly **higher** than your current free space (e.g., if you have `940G` free, enter **`950G`** or **`1T`** to trigger the alert).
     * The expression will look like:
       ```text
       last(/test-ubuntu-vm/vfs.fs.size[/,free]) < 950G
       ```
4. Click **Add**.
5. Verify that the alert fires on the Zabbix Dashboard and dispatches to your Telegram channel.
6. **To Resolve**: Edit the trigger and lower the threshold back to a production level (e.g., `< 10G` or `< 5G`).
