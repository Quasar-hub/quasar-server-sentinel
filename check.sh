#!/bin/bash

# Configuration
RPC_ENDPOINT="http://localhost:26657"
VALIDATOR_ADDRESS=""  # Validator address in hex format 849ASD.....
CHAIN_ID=""          # Chain identifier
LOG_DIR="$HOME/cosmos_logs"  # Log directory
LOG_FILE="${LOG_DIR}/cosmos_monitor.log"  # Log file path
BOT_TOKEN=""         # Telegram bot token
CHAT_ID=""          # Group ID
THREAD_ID=""        # Thread ID within the group
ALERT_MSG="⚠️ Validator missed more than 10 blocks on $(hostname) for chain ${CHAIN_ID}."
THRESHOLD=10        # Alert threshold

# Create directory and log file if they don't exist
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# Function to send Telegram notification to specified thread
send_tg_message() {
  local message=$1
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d message_thread_id="${THREAD_ID}" \
    -d text="${message}" \
    -d parse_mode="HTML"
}

# Function to check last N blocks
check_missed_blocks_in_last_n() {
  local N=10  # Number of blocks to check
  local missed_blocks=0

  # Get latest block height
  LATEST_HEIGHT=$(curl -s "${RPC_ENDPOINT}/status" | jq -r '.result.sync_info.latest_block_height')

  # Check last N blocks
  for ((i=0; i<N; i++)); do
    BLOCK_HEIGHT=$((LATEST_HEIGHT - i))
    BLOCK=$(curl -s "${RPC_ENDPOINT}/block?height=${BLOCK_HEIGHT}")

    # Check if validator signed the block
    SIGNED=$(echo "$BLOCK" | jq -r \
      --arg VAL "$VALIDATOR_ADDRESS" \
      '.result.block.last_commit.signatures[] | select(.validator_address == $VAL)')

    if [[ -z "$SIGNED" ]]; then
      missed_blocks=$((missed_blocks + 1))
    fi
  done

  # Log and send notification if threshold is reached
  if (( missed_blocks >= THRESHOLD )); then
    LOG_ENTRY="$(date): Validator missed ${missed_blocks} out of last ${N} blocks!"
    echo "$LOG_ENTRY" | tee -a "$LOG_FILE"
    send_tg_message "$ALERT_MSG"
  fi
}

# Run check
check_missed_blocks_in_last_n
