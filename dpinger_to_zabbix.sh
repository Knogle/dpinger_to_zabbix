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
