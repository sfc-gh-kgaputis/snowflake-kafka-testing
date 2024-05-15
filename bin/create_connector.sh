#!/bin/bash

# Check if a valid argument was passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_json_file>"
    exit 1
fi

# Check if the provided file exists
if [ ! -f "$1" ]; then
    echo "Error: File '$1' not found."
    exit 2
fi

# Substitute environment variables in the JSON template
exported_json=$(envsubst < "$1")
echo "${exported_json}"

# Check if envsubst succeeded
if [ $? -ne 0 ]; then
    echo "Failed to substitute environment variables in JSON file."
    exit 3
fi

# Deploy the connector with the substituted JSON
echo "${exported_json}" | curl -X POST -H "Content-Type: application/json" --data @- http://localhost:8083/connectors | jq

# Check if the curl command was successful
if [ $? -eq 0 ]; then
    echo "Kafka Connect API call was successful (check output for errors)."
else
    echo "Failed to make API call to Kafka Connect."
    exit 4
fi