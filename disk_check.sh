#!/bin/bash

# Telegram Configuration
BOT_TOKEN=""        # Telegram bot token
CHAT_ID=""         # Group ID
THREAD_ID=""       # Thread ID within the group

# Function to send Telegram notification
send_tg_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d message_thread_id="${THREAD_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML"
}

# Disk check
# Get free space on root partition in gigabytes
FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

# Check free disk space
if [ ${FREE_SPACE} -lt 100 ]; then
    # Prepare Telegram notification
    DISK_ALERT="⚠️ Critical low disk space on $(hostname)!
Free: ${FREE_SPACE}GB
Threshold: 100GB

❗️ Disk cleanup required!"
    
    # Send Telegram notification
    send_tg_message "$DISK_ALERT"
    
    # Log critical event to system log
    logger "Disk Monitor: Free space is below 100GB (Current: ${FREE_SPACE}GB)"
fi 
