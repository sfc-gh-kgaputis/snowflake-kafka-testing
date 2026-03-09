#!/bin/bash
set -euo pipefail

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq to continue."
    exit 1
fi

KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"

# Get list of connectors
connectors=$(curl -s -X GET "$KAFKA_CONNECT_URL/connectors")
connector_list=$(echo "$connectors" | jq -r '.[]')

if [ -z "$connector_list" ]; then
    echo "No connectors found at $KAFKA_CONNECT_URL."
    exit 0
fi

# For each connector, get its status
for connector in $connector_list; do
    echo "Getting connector: $connector"
    curl -s -X GET "$KAFKA_CONNECT_URL/connectors/$connector/status" | jq
done
