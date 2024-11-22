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

# Get total used memory in gigabytes
USED_RAM=$(free -g | grep Mem | awk '{print $3}')

# Check if usage exceeds 14GB
if [ ${USED_RAM} -ge 15 ]; then
    # Prepare Telegram notification
    ALERT_MSG="⚠️ High RAM usage on $(hostname)!
Used: ${USED_RAM}GB
Threshold: 15GB

🔄 Initiating server reboot."
    
    # Send Telegram notification
    send_tg_message "$ALERT_MSG"
    
    # Log to system log
    logger "RAM Monitor: Memory usage exceeded 15GB (Current: ${USED_RAM}GB). Executing immediate reboot..."
    
    # Execute reboot with sudo
    sudo /sbin/reboot
#else
#    logger "RAM Monitor: Memory usage is normal (${USED_RAM}GB)"
fi
