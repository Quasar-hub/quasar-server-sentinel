#!/bin/bash

# Get the directory where the script is located
# This ensures we can find the config file regardless of where the script is called from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load configuration variables from config.sh (thresholds, Telegram settings, etc.)
source "${SCRIPT_DIR}/config.sh"

# Add after source command
if [ -z "$RAM_THRESHOLD" ] || [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ -z "$THREAD_ID" ]; then
    logger "RAM Monitor: Configuration error - missing required variables"
    exit 1
fi

# Function to send notifications via Telegram
# Parameters:
#   $1 - message text to send
send_tg_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d message_thread_id="${THREAD_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML"
}

# Get current RAM usage in gigabytes
# free -g     - show memory info in GB
# grep Mem    - get the line with RAM info
# awk '{print $3}' - get the 3rd column (used memory)
USED_RAM=$(free -g | grep Mem | awk '{print $3}')

# Add after USED_RAM definition
if [ -z "$USED_RAM" ]; then
    logger "RAM Monitor: Error getting RAM usage information"
    exit 1
fi

# Check if RAM usage is above the threshold
# If used RAM is greater or equal to RAM_THRESHOLD (defined in config.sh)
if [ ${USED_RAM} -ge ${RAM_THRESHOLD} ]; then
    # Format alert message with current RAM usage
    FORMATTED_ALERT=$(printf "$RAM_ALERT_MSG" "$USED_RAM")
    
    # Send notification to Telegram channel/group
    send_tg_message "$FORMATTED_ALERT"
    
    # Write event to system log for future reference
    logger "RAM Monitor: Memory usage exceeded ${RAM_THRESHOLD}GB (Current: ${USED_RAM}GB)"

    # Reboot the system when RAM usage is too high
    # Using full path to reboot command for security
    # Requires sudo privileges for the user running the script
    sudo /sbin/reboot
fi
