# Step-by-Step Walkthrough: Adding a Host, Creating a Trigger, & Simulating an Alert

This document provides a concrete, end-to-end sample tutorial on using the Zabbix Web UI. You will learn how to add a target VM (`web-server-prod`), configure a custom CPU warning trigger, simulate high CPU load on the VM, and verify the resulting alert.

---

## Tutorial Objective
*   **Target VM**: `test-ubuntu-vm` at IP `10.0.100.20`
*   **Goal**: Monitor the VM, create an alert trigger that fires when CPU utilization exceeds **80%**, simulate a high CPU load to fire the alert, and acknowledge/clear it in the dashboard.

---

## Prerequisites: How to Get or Generate the PSK Key
Before adding the host to the UI, you need the 64-character PSK hex key. 

*   **Option 1: Read the existing key from the VM**
    *   *On Ubuntu*: Run `sudo cat /etc/zabbix/zabbix_agent2.psk`
    *   *On Windows*: Run `Get-Content "C:\Program Files\Zabbix Agent 2\zabbix_agent2.psk"` in PowerShell.
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
    *   **Host name**: `test-ubuntu-vm` *(Must match the `Hostname` parameter in the VM's agent config)*
    *   **Templates**: Search and select `Linux by Zabbix agent`.
    *   **Host groups**: Type and select `Virtual Machines`.
    *   **Interfaces**: Click **Add** -> select **Agent**:
        *   **IP address**: `10.0.100.20`
        *   **Port**: `10050`
4.  Fill in the **Encryption** tab (for PSK):
    *   **Connections to host**: Select `PSK`.
    *   **Connections from host**: Check `PSK`.
    *   **PSK identity**: `monitoring-stack-psk`
    *   **PSK**: Paste your 64-character hex key (e.g. `d3b07384...`).
5.  Click the blue **Add** button.
6.  *Wait ~60 seconds.* Verify that the **ZBX** availability indicator icon in the Hosts table turns **green**.

---

## Step 2: Create a Custom CPU Alert Trigger

Although the standard template already alerts when CPU is extremely high, we will create a custom host-specific alert trigger for testing.

1.  Go to **Data collection** -> **Hosts**.
2.  Locate your newly added host `test-ubuntu-vm` and click on **Triggers** in its row.
3.  Click **Create trigger** in the top-right corner.
4.  Configure the Trigger:
    *   **Name**: `High CPU Load Detected (Over 80%) on test-ubuntu-vm`
    *   **Severity**: Select 🟠 **Average**.
    *   **Expression**: Click **Add** to build the formula:
        *   *Item*: Click **Select** -> choose `CPU utilization`.
        *   *Function*: Select `last()` (most recent value).
        *   *Result*: Select `>` (greater than) and enter `80`.
        *   Click **Insert**. The expression should read:
            ```text
            last(/test-ubuntu-vm/system.cpu.util) > 80
            ```
    *   **Description**: `Trigger fires when CPU utilization exceeds 80% on the target VM.`
5.  Click **Add**.

---

## Step 3: Simulate High CPU Load on the Target VM

To test the trigger, log in to the monitored target VM (`test-ubuntu-vm` at `10.0.100.20`) via SSH and execute a stress test to force CPU utilization above 80%.

1.  SSH into the VM:
    ```bash
    ssh username@10.0.100.20
    ```
2.  Install the CPU stress tool:
    ```bash
    sudo apt update && sudo apt install -y stress
    ```
3.  Launch the CPU stress test (occupy all cores):
    ```bash
    # Run a CPU stress test for 5 minutes (300 seconds)
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
