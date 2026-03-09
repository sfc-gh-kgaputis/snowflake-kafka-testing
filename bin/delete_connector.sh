#!/bin/bash
set -euo pipefail

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq to continue."
    exit 1
fi

KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"

# Check if a valid argument was passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <connector_name>"
    echo ""
    echo "Set KAFKA_CONNECT_URL to override the default ($KAFKA_CONNECT_URL)."
    exit 1
fi

CONNECTOR_NAME="$1"

# Delete the connector
echo "Deleting connector '$CONNECTOR_NAME' via $KAFKA_CONNECT_URL ..."
response=$(curl -s -X DELETE "$KAFKA_CONNECT_URL/connectors/$CONNECTOR_NAME")

if [ $? -eq 0 ]; then
    echo "${response}" | jq
else
    echo "Failed to make API call to Kafka Connect."
    exit 2
fi
