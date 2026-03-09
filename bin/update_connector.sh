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

# Extract the connector name from the JSON file
connector_name=$(jq -r '.name' "$JSON_FILE")

if [ -z "$connector_name" ] || [ "$connector_name" = "null" ]; then
    echo "Failed to extract connector name from JSON file."
    exit 3
fi

# Substitute environment variables in the JSON template and extract the config
exported_json=$(jq '.config' "$JSON_FILE" | envsubst)

# Update the connector with the substituted JSON
echo "Updating connector '$connector_name' via $KAFKA_CONNECT_URL ..."
response=$(echo "${exported_json}" | curl -s -X PUT -H "Content-Type: application/json" --data @- "$KAFKA_CONNECT_URL/connectors/${connector_name}/config")

if [ $? -eq 0 ]; then
    echo "${response}" | jq
else
    echo "Failed to make API call to Kafka Connect."
    exit 4
fi
