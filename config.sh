#!/bin/bash

# Telegram configuration
export BOT_TOKEN=""
export CHAT_ID=""
export THREAD_ID=""

# Monitoring thresholds
export DISK_THRESHOLD=300  # Free space threshold in GB
export RAM_THRESHOLD=100   # RAM usage threshold in GB
export BLOCKS_THRESHOLD=10 # Missed blocks threshold

# Log configuration
export LOG_DIR="./logs"
export LOG_FILE="${LOG_DIR}/cosmos_monitor.log"

# Alert messages
export DISK_ALERT_MSG="⚠️ Critical low disk space on $(hostname)!
Free space: %dGB
Threshold: ${DISK_THRESHOLD}GB

❗️ Disk cleanup required!"

export RAM_ALERT_MSG="⚠️ High RAM usage on $(hostname)!
Used: %dGB
Threshold: ${RAM_THRESHOLD}GB

🔄 Server restart required."

export BLOCKS_ALERT_MSG="⚠️ Validator for %s missed more than ${BLOCKS_THRESHOLD} blocks on $(hostname)." 
