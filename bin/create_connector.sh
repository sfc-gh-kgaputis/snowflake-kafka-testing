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
    echo "Usage: $0 <path_to_json_file>"
    echo ""
    echo "Set KAFKA_CONNECT_URL to override the default ($KAFKA_CONNECT_URL)."
    exit 1
fi

JSON_FILE="$1"

# Check if the provided file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File '$JSON_FILE' not found."
    exit 2
fi

# Substitute environment variables in the JSON template
exported_json=$(envsubst < "$JSON_FILE")

# Deploy the connector with the substituted JSON
echo "Creating connector from $JSON_FILE via $KAFKA_CONNECT_URL ..."
response=$(echo "${exported_json}" | curl -s -X POST -H "Content-Type: application/json" --data @- "$KAFKA_CONNECT_URL/connectors")

if [ $? -eq 0 ]; then
    echo "${response}" | jq
else
    echo "Failed to make API call to Kafka Connect."
    exit 3
fi
