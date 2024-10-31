### dpinger to Zabbix

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation and Setup](#installation-and-setup)
4. [The Script](#the-script)
5. [Script Explanation](#script-explanation)
6. [Zabbix Configuration](#zabbix-configuration)
7. [Automation](#automation)
8. [GitHub Project Structure](#github-project-structure)
9. [Conclusion](#conclusion)

---

## Overview

This guide provides a Bash script that performs the following tasks:

1. **Retrieve Gateway List**: Dynamically fetches all configured gateways on the OPNsense appliance.
2. **Query Packet Loss with dpinger**: Retrieves packet loss information for each gateway using dpinger.
3. **Send Data to Zabbix**: Transmits the collected data to the Zabbix server using `zabbix_sender`.

---

## Prerequisites

Before proceeding, ensure that the following components are available:

- **OPNsense Appliance** with dpinger installed.
- **Zabbix Server** accessible and properly configured.
- **zabbix_sender** installed on the OPNsense appliance.
- **jq** installed on the OPNsense appliance for JSON parsing.
- **Bash Shell** (default on OPNsense).

---

## Installation and Setup

### 1. Install Required Tools

**a. Install `jq`**

`jq` is a lightweight and flexible command-line JSON processor. It is essential for parsing JSON output from `dpingerctl`.

```sh
pkg install jq
```

**b. Install `zabbix_sender`**

If not already installed, install `zabbix_sender` to facilitate sending data to the Zabbix server.

```sh
pkg install zabbix-sender
```

### 2. Create the Script

Create a new file named `dpinger_to_zabbix.sh` in your desired directory, for example, `/usr/local/bin/`.

```sh
touch /usr/local/bin/dpinger_to_zabbix.sh
chmod +x /usr/local/bin/dpinger_to_zabbix.sh
```

---

## The Script

Below is the complete Bash script. Ensure to replace the placeholder values with your actual Zabbix server details.

```bash
#!/bin/bash

###############################################################################
# dpinger_to_zabbix.sh
#
# This script retrieves packet loss data from dpinger for all available
# gateways on an OPNsense appliance and sends the data to a Zabbix server.
#
# Requirements:
# - Bash Shell
# - jq
# - zabbix_sender
#
# Configuration:
# - ZABBIX_SERVER: IP or hostname of the Zabbix server.
# - ZABBIX_HOST: Name of the OPNsense host as configured in Zabbix.
# - DPINGER_STATUS_CMD: Command to retrieve dpinger status in JSON format.
#
# Usage:
# Run the script manually or set it up as a cron job.
#
# Author: Fabian Druschke
# License: MIT
###############################################################################

# Configuration
ZABBIX_SERVER="your_zabbix_server_ip_or_hostname"
ZABBIX_HOST="your_opnsense_host_name_in_zabbix"
ZABBIX_SENDER="/usr/local/bin/zabbix_sender"  # Path to zabbix_sender
DPINGER_STATUS_CMD="/usr/local/sbin/dpingerctl -j status"  # dpingerctl command

# Temporary file for zabbix_sender input
TEMP_FILE="/tmp/zabbix_data.tmp"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to retrieve gateways
get_gateways() {
    log "Retrieving gateways using dpingerctl..."
    GW_JSON=$($DPINGER_STATUS_CMD 2>/dev/null)
    if [ $? -ne 0 ]; then
        log "Error: Failed to execute dpingerctl."
        exit 1
    fi

    echo "$GW_JSON" | jq -r '.gateways | to_entries[] | "\(.key) \(.value.packetloss)"'
}

# Function to send data to Zabbix
send_to_zabbix() {
    log "Preparing data for Zabbix sender..."
    > "$TEMP_FILE"  # Truncate or create the temporary file

    while read -r gw_name packetloss; do
        # Replace spaces with underscores in gateway names for Zabbix keys
        gw_key=$(echo "$gw_name" | tr ' ' '_')
        echo "$ZABBIX_HOST dpinger.packetloss[$gw_key] $packetloss" >> "$TEMP_FILE"
    done < <(get_gateways)

    log "Sending data to Zabbix server ($ZABBIX_SERVER)..."
    $ZABBIX_SENDER -z "$ZABBIX_SERVER" -i "$TEMP_FILE"
    if [ $? -ne 0 ]; then
        log "Error: Failed to send data to Zabbix."
        exit 1
    fi

    log "Data successfully sent to Zabbix."
    rm -f "$TEMP_FILE"
}

# Main execution
send_to_zabbix
```

---

## Script Explanation

### 1. Configuration Section

- **ZABBIX_SERVER**: Replace `"your_zabbix_server_ip_or_hostname"` with your actual Zabbix server's IP address or hostname.
- **ZABBIX_HOST**: Replace `"your_opnsense_host_name_in_zabbix"` with the name of your OPNsense host as it appears in Zabbix.
- **ZABBIX_SENDER**: Path to the `zabbix_sender` executable. Typically `/usr/local/bin/zabbix_sender`.
- **DPINGER_STATUS_CMD**: Command to retrieve dpinger status in JSON format.

### 2. Logging Function

The `log` function timestamps and outputs messages, aiding in troubleshooting and monitoring script execution.

### 3. `get_gateways` Function

- Executes the `dpingerctl -j status` command to retrieve gateway information in JSON format.
- Parses the JSON using `jq` to extract gateway names and their corresponding packet loss percentages.
- Outputs lines in the format: `<gateway_name> <packet_loss>`

**Example Output:**

```
gateway1 0.0
gateway2 5.0
gateway3 100.0
```

### 4. `send_to_zabbix` Function

- Prepares the data for transmission by formatting each gateway's packet loss into a format recognized by Zabbix.
- Uses `zabbix_sender` to send the data to the specified Zabbix server.
- Cleans up the temporary file after successful transmission.

**Zabbix Sender Input Format:**

```
<host> <key> <value>
```

**Example:**

```
opnsense_host dpinger.packetloss[gateway1] 0.0
opnsense_host dpinger.packetloss[gateway2] 5.0
opnsense_host dpinger.packetloss[gateway3] 100.0
```

### 5. Main Execution

Calls the `send_to_zabbix` function to perform the entire process.

---

## Zabbix Configuration

To visualize and monitor the packet loss data in Zabbix, perform the following configurations:

### 1. Create a New Template

1. **Navigate to**: `Configuration` → `Templates` in your Zabbix frontend.
2. **Click**: `Create template`.
3. **Set**:
   - **Template name**: `DPinger Packet Loss`
   - **Groups**: Assign to an appropriate group, e.g., `Templates/Network`.
4. **Click**: `Add`.

### 2. Add Items to the Template

For each gateway, you'll need to create an item to receive the packet loss data.

1. **Within the Template**, go to the `Items` tab.
2. **Click**: `Create item`.
3. **Set**:
   - **Name**: `Packet Loss for {#GATEWAY}`
   - **Type**: `Zabbix trapper`
   - **Key**: `dpinger.packetloss[{#GATEWAY}]`
   - **Type of information**: `Numeric (float)`
   - **Units**: `%`
   - **Applications**: Create or assign to an existing application, e.g., `Network`.
4. **Click**: `Add`.

*Repeat the above steps for each gateway or set up Low-Level Discovery (LLD) for dynamic discovery (advanced).*

### 3. Link the Template to the Host

1. **Navigate to**: `Configuration` → `Hosts`.
2. **Select** your OPNsense host.
3. **Go to** the `Templates` tab.
4. **Click**: `Link new templates`.
5. **Select**: `DPinger Packet Loss`.
6. **Click**: `Add` → `Update`.

---

## Automation

To ensure the script runs periodically and keeps your Zabbix server updated with the latest packet loss data, set up a cron job.

### 1. Edit the Crontab

Open the crontab editor for the root user (or appropriate user):

```sh
crontab -e
```

### 2. Add the Cron Job

Add the following line to execute the script every 5 minutes:

```sh
*/5 * * * * /usr/local/bin/dpinger_to_zabbix.sh >> /var/log/dpinger_to_zabbix.log 2>&1
```

**Explanation:**

- `*/5 * * * *`: Runs the script every 5 minutes.
- `/usr/local/bin/dpinger_to_zabbix.sh`: Path to your script.
- `>> /var/log/dpinger_to_zabbix.log 2>&1`: Redirects both standard output and errors to a log file for troubleshooting.

### 3. Verify Permissions

Ensure the script is executable and has the necessary permissions:

```sh
chmod +x /usr/local/bin/dpinger_to_zabbix.sh
```

---

## GitHub Project Structure

A well-organized GitHub repository facilitates collaboration and ease of use. Below is a recommended structure for your project.

```
dpinger-to-zabbix/
├── dpinger_to_zabbix.sh
├── README.md
├── LICENSE
└── .gitignore
```

### 1. `dpinger_to_zabbix.sh`

The main Bash script as provided above.

### 2. `README.md`

Provides detailed information about the project, setup instructions, usage, and more.

**Example `README.md`:**

```markdown
# dpinger-to-zabbix

This project contains a Bash script that retrieves packet loss data from dpinger on OPNsense appliances and sends the data to a Zabbix server.

## Prerequisites

- **OPNsense Appliance** with dpinger installed.
- **Zabbix Server** accessible and configured.
- **zabbix_sender** installed on the OPNsense appliance.
- **jq** installed on the OPNsense appliance.
- **Bash Shell** (default on OPNsense).

## Installation

### 1. Install Required Tools

**Install `jq`:**

```sh
pkg install jq
```

**Install `zabbix_sender`:**

```sh
pkg install zabbix-sender
```

### 2. Download the Script

Clone the repository or download the `dpinger_to_zabbix.sh` script.

```sh
git clone https://github.com/yourusername/dpinger-to-zabbix.git
cd dpinger-to-zabbix
chmod +x dpinger_to_zabbix.sh
```

### 3. Configure the Script

Edit the `dpinger_to_zabbix.sh` script to set your Zabbix server details.

```sh
nano dpinger_to_zabbix.sh
```

Update the following variables:

```bash
ZABBIX_SERVER="your_zabbix_server_ip_or_hostname"
ZABBIX_HOST="your_opnsense_host_name_in_zabbix"
ZABBIX_SENDER="/usr/local/bin/zabbix_sender"
DPINGER_STATUS_CMD="/usr/local/sbin/dpingerctl -j status"
```

### 4. Set Up a Cron Job

To run the script every 5 minutes:

```sh
crontab -e
```

Add the following line:

```sh
*/5 * * * * /usr/local/bin/dpinger_to_zabbix.sh >> /var/log/dpinger_to_zabbix.log 2>&1
```

## Usage

The script automatically retrieves packet loss data for all configured gateways and sends it to the specified Zabbix server. Data can be viewed and monitored within Zabbix.

## Zabbix Configuration

1. **Create a Template**: Add items with keys `dpinger.packetloss[{#GATEWAY}]` as Zabbix trapper type.
2. **Link the Template**: Assign the template to your OPNsense host in Zabbix.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
```

### 3. `LICENSE`

Include a license file to specify the terms under which your project is distributed. The [MIT License](LICENSE) is commonly used for open-source projects.

**Example `LICENSE`:**

```markdown
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy...
```

### 4. `.gitignore`

Specify files and directories to ignore in your Git repository.

**Example `.gitignore`:**

```gitignore
# Temporary files
*.tmp
*.log

# Scripts permissions (optional)
*.sh
```

---

## Conclusion

By following this guide, you can effectively monitor the packet loss of your gateways on OPNsense appliances and integrate the data into Zabbix without relying on Python. The provided Bash script leverages `dpingerctl`, `jq`, and `zabbix_sender` to achieve dynamic and automated monitoring.

This setup ensures flexibility and scalability, allowing for easy addition of new gateways without manual intervention. The detailed documentation and structured GitHub project setup facilitate collaboration and maintenance.

### Troubleshooting Tips

- **Permissions**: Ensure the script has execute permissions and that `zabbix_sender` has the necessary rights to send data.
- **Dependencies**: Verify that `jq` and `zabbix_sender` are correctly installed and accessible at the specified paths.
- **Logs**: Check `/var/log/dpinger_to_zabbix.log` for any errors or issues during script execution.
- **Zabbix Server**: Ensure the Zabbix server is reachable from the OPNsense appliance and that firewall rules allow communication on the required ports.

Feel free to customize the script further to fit your specific requirements. If you encounter any issues or have suggestions for improvements, consider contributing to the GitHub repository or reaching out for support.

