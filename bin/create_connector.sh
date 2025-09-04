#!/bin/bash

# Check if jq is available
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to continue."
    exit 1
fi

# Set default Kafka Connect URL
KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"

# Check if a valid argument was passed
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <path_to_json_file> [kafka_connect_url]"
    echo ""
    echo "Arguments:"
    echo "  path_to_json_file    Path to the connector JSON configuration file"
    echo "  kafka_connect_url    Kafka Connect REST API URL (optional)"
    echo ""
    echo "Default Kafka Connect URL: $KAFKA_CONNECT_URL"
    echo ""
    echo "You can also set KAFKA_CONNECT_URL environment variable."
    echo ""
    echo "Examples:"
    echo "  $0 my-connector.json"
    echo "  $0 my-connector.json http://kafka-connect:8083"
    echo "  KAFKA_CONNECT_URL=http://remote:8083 $0 my-connector.json"
    exit 1
fi

JSON_FILE="$1"

# Use provided URL or default
if [ "$#" -eq 2 ]; then
    KAFKA_CONNECT_URL="$2"
fi

# Check if the provided file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File '$JSON_FILE' not found."
    exit 2
fi

echo "Using Kafka Connect URL: $KAFKA_CONNECT_URL"

# Substitute environment variables in the JSON template
exported_json=$(envsubst < "$JSON_FILE")

# Check if envsubst succeeded
if [ $? -ne 0 ]; then
    echo "Failed to substitute environment variables in JSON file."
    exit 3
fi

# Deploy the connector with the substituted JSON
echo "${exported_json}" | curl -X POST -H "Content-Type: application/json" --data @- "$KAFKA_CONNECT_URL/connectors" | jq

# Check if the curl command was successful
if [ $? -eq 0 ]; then
    echo "Kafka Connect API call was successful (check output for errors)."
else
    echo "Failed to make API call to Kafka Connect."
    exit 4
fi