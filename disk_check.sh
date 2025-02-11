#!/bin/bash

# Get the directory where the script is located
# This ensures we can find the config file regardless of where the script is called from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load configuration variables from config.sh (thresholds, Telegram settings, etc.)
source "${SCRIPT_DIR}/config.sh"

# Add after source command
if [ -z "$DISK_THRESHOLD" ] || [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ -z "$THREAD_ID" ]; then
    logger "Disk Monitor: Configuration error - missing required variables"
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

# Get available disk space in gigabytes
# df -BG  - show disk space in GB units
# awk 'NR==2 {print $4}' - get the 4th column (free space) from the second line
# sed 's/G//' - remove the 'G' suffix from the number
FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

# Add after FREE_SPACE definition
if [ -z "$FREE_SPACE" ]; then
    logger "Disk Monitor: Error getting disk space information"
    exit 1
fi

# Check if free space is below the threshold
# If free space is less than DISK_THRESHOLD (defined in config.sh), send alert
if [ ${FREE_SPACE} -lt ${DISK_THRESHOLD} ]; then
    # Format alert message with current free space value
    FORMATTED_ALERT=$(printf "$DISK_ALERT_MSG" "$FREE_SPACE")
    
    # Send notification to Telegram channel/group
    send_tg_message "$FORMATTED_ALERT"
    
    # Write event to system log for future reference
    logger "Disk Monitor: Free space is below ${DISK_THRESHOLD}GB (Current: ${FREE_SPACE}GB)"
fi 
