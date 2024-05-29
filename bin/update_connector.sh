#!/bin/bash

# Check if a valid argument was passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_json_file>"
    exit 1
fi

json_file=$1

# Check if the provided JSON file exists
if [ ! -f "$json_file" ]; then
    echo "Error: File '$json_file' not found."
    exit 2
fi

# Check if jq is available
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to continue."
    exit 1
fi

# Extract the connector name from the JSON file
connector_name=$(jq -r '.name' "$json_file")

# Check if the connector name was successfully extracted
if [ -z "$connector_name" ]; then
    echo "Failed to extract connector name from JSON file."
    exit 3
fi

# Substitute environment variables in the JSON template and extract the config
exported_json=$(jq '.config' "$json_file" | envsubst)

# Check if envsubst succeeded
if [ $? -ne 0 ]; then
    echo "Failed to substitute environment variables in JSON file."
    exit 4
fi

# Update the connector with the substituted JSON
update_response=$(echo "${exported_json}" | curl -X PUT -H "Content-Type: application/json" --data @- http://localhost:8083/connectors/${connector_name}/config)

# Check if the curl command was successful
if [ $? -eq 0 ]; then
    echo "Kafka Connect API call was successful (check output for errors)."
    echo "${update_response}" | jq
else
    echo "Failed to make API call to Kafka Connect."
    exit 5
fi
