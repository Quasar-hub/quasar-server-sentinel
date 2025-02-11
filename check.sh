#!/bin/bash

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source configuration file
source "${SCRIPT_DIR}/config.sh"

# Check if all required parameters are provided
# Usage: ./check.sh <RPC_ENDPOINT> <VALIDATOR_ADDRESS> <CHAIN_ID> <CHAIN_NAME> [LOG_DIR]
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <RPC_ENDPOINT> <VALIDATOR_ADDRESS> <CHAIN_ID> <CHAIN_NAME> [LOG_DIR]"
  echo "Example: $0 http://localhost:26657 76A8A9A8151255E9E69E89499CFE9CB86F cosmoshub-4 cosmos"
  echo "Example: $0 http://localhost:26657 76A8A9A8151255E9E69E89499CFE9CB86F cosmoshub-4 cosmos ./logs"
  exit 1
fi

# Script parameters
RPC_ENDPOINT="$1"      # Primary RPC endpoint (usually local)
VALIDATOR_ADDRESS="$2"  # Validator address in hex format 849ASD.....
CHAIN_ID="$3"          # Chain ID (e.g., cosmoshub-4, osmosis-1)
CHAIN_NAME="$4"        # Chain name for endpoint lookup (e.g., cosmos, osmosis)
LOG_DIR="${5:-$LOG_DIR}"  # Use provided LOG_DIR or default from config

# Create log directory and file if they don't exist
mkdir -p "${LOG_DIR}"  # Create logs directory if it doesn't exist
touch "${LOG_FILE}"    # Create log file if it doesn't exist

# Function to send messages to Telegram
send_tg_message() {
  local message=$1
  local response=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "message_thread_id=${THREAD_ID}" \
    -d "text=${message}" \
    -d "parse_mode=HTML")
    
  if echo "$response" | grep -q '"ok":true'; then
    echo "Message sent successfully to Telegram"
  else
    echo "Failed to send message to Telegram. Error response:"
    echo "$response"
  fi
}

# Main function to check missed blocks
# Checks last N blocks and counts how many were missed by the validator
check_missed_blocks_in_last_n() {
  local N=10                          # Number of blocks to check
  local missed_blocks=0               # Counter for missed blocks
  local current_endpoint="$RPC_ENDPOINT"  # Current working endpoint
  local failed_attempts=0             # Counter for failed endpoint attempts

  # Get latest block height from current endpoint
  LATEST_HEIGHT=$(curl -s "${current_endpoint}/status" | jq -r '.result.sync_info.latest_block_height')
  
  # If primary endpoint fails, get and try backup endpoints
  if [[ -z "$LATEST_HEIGHT" || "$LATEST_HEIGHT" == "null" ]]; then
    echo "Local endpoint not responding, searching for backup endpoints..."
    
    # Get backup endpoints from chain_endpoints.py
    echo "Running: python3 ${SCRIPT_DIR}/chain_endpoints.py $CHAIN_NAME"
    if ! BACKUP_ENDPOINTS=$(python3 "${SCRIPT_DIR}/chain_endpoints.py" "$CHAIN_NAME" 2>/dev/null); then
        echo "Error running chain_endpoints.py"
        BACKUP_ENDPOINTS=""
    fi
    SCRIPT_EXIT_CODE=$?
    echo "Script exit code: $SCRIPT_EXIT_CODE"
    echo "Backup endpoints: $BACKUP_ENDPOINTS"
    
    if [ $SCRIPT_EXIT_CODE -eq 0 ] && [ ! -z "$BACKUP_ENDPOINTS" ]; then
        IFS=' ' read -r -a endpoints <<< "$BACKUP_ENDPOINTS"
        echo "Loaded ${#endpoints[@]} backup endpoints for ${CHAIN_NAME}"
        
        # Try each backup endpoint
        for endpoint in "${endpoints[@]}"; do
            echo "Trying endpoint: $endpoint"
            LATEST_HEIGHT=$(curl -s "${endpoint}/status" | jq -r '.result.sync_info.latest_block_height')
            if [[ ! -z "$LATEST_HEIGHT" && "$LATEST_HEIGHT" != "null" ]]; then
                current_endpoint="$endpoint"
                echo "Found working endpoint: $endpoint"
                break
            fi
            ((failed_attempts++))
            echo "Endpoint failed: $endpoint"
        done
    else
        echo "Failed to get backup endpoints"
        declare -a endpoints=()
    fi
  fi

  # Handle case when all endpoints failed
  if [[ -z "$LATEST_HEIGHT" || "$LATEST_HEIGHT" == "null" ]]; then
    local msg="🔴 $CHAIN_ID - no response from $RPC_ENDPOINT or backup endpoints (tried ${failed_attempts} additional endpoints) on $(hostname)"
    local log_msg="$(date): $CHAIN_ID - all endpoints failed after ${failed_attempts} attempts!"
    echo "$log_msg" >> "$LOG_FILE"
    send_tg_message "$msg"
    return 1
  fi

  # Check last N blocks for missed signatures
  for ((i=0; i<N; i++)); do
    BLOCK_HEIGHT=$((LATEST_HEIGHT - i))
    BLOCK=$(curl -s "${current_endpoint}/block?height=${BLOCK_HEIGHT}")
    
    SIGNED=$(echo "$BLOCK" | jq -r \
      --arg VAL "$VALIDATOR_ADDRESS" \
      '.result.block.last_commit.signatures[] | select(.validator_address == $VAL)')

    # Increment counter if block was missed
    if [[ -z "$SIGNED" ]]; then
      echo "❌ Block $BLOCK_HEIGHT not signed" | tee -a "$LOG_FILE"
      ((missed_blocks++))
    fi
  done

  # If missed blocks exceed threshold, log and send alert
  if (( missed_blocks >= THRESHOLD )); then
    LOG_ENTRY="$(date): Validator missed ${missed_blocks} blocks on $(hostname)! for ${CHAIN_ID} (using endpoint: ${current_endpoint})"
    echo "$LOG_ENTRY" | tee -a "$LOG_FILE"
    
    send_tg_message "$ALERT_MSG"
  fi
}

# Run the check
check_missed_blocks_in_last_n
