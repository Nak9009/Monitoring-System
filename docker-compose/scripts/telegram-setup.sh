#!/usr/bin/env bash
# ==============================================================================
# Telegram Bot Integration Test Script
# Tests the Telegram Bot API credentials and sends a test message.
# ==============================================================================

set -euo pipefail

# Read Telegram Token and Chat ID from .env if it exists
ENV_FILE="$(dirname "$0")/../.env"
BOT_TOKEN=""
CHAT_ID=""

if [ -f "$ENV_FILE" ]; then
    # Load variables from .env
    BOT_TOKEN=$(grep -E "^TELEGRAM_BOT_TOKEN=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    CHAT_ID=$(grep -E "^TELEGRAM_CHAT_ID=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
fi

# Fallback to prompt if not found in .env
if [ -z "$BOT_TOKEN" ]; then
    read -rp "Enter Telegram Bot Token: " BOT_TOKEN
fi

if [ -z "$CHAT_ID" ]; then
    read -rp "Enter Telegram Chat ID/Channel ID: " CHAT_ID
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Error: Both BOT_TOKEN and CHAT_ID are required."
    exit 1
fi

echo "Testing Telegram Bot Connection..."
# Test API
API_URL="https://api.telegram.org/bot$BOT_TOKEN/getMe"
RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ]; then
    echo "Error: Invalid Token or API connection failed. HTTP Code: $HTTP_CODE"
    echo "Response: $BODY"
    exit 1
fi

BOT_NAME=$(echo "$BODY" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
echo "Success: Connected to bot @$BOT_NAME"

# Send Test Message
echo "Sending test message to Chat ID: $CHAT_ID..."
MESSAGE="🚨 *Monitoring Alert Test* 🚨

*Status:* OK
*Host:* mon-docker-host
*Message:* If you are reading this, your Telegram Bot integration is working perfectly!
*Time:* $(date)"

SEND_RESPONSE=$(curl -s -w "\n%{http_code}" "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  --data "chat_id=$CHAT_ID" \
  --data-urlencode "text=$MESSAGE" \
  --data "parse_mode=Markdown")
SEND_HTTP_CODE=$(echo "$SEND_RESPONSE" | tail -n1)
SEND_BODY=$(echo "$SEND_RESPONSE" | sed '$d')

if [ "$SEND_HTTP_CODE" -ne 200 ]; then
    echo "Error: Failed to send message. HTTP Code: $SEND_HTTP_CODE"
    echo "Response: $SEND_BODY"
    exit 1
fi

echo "Success! Message sent successfully."
