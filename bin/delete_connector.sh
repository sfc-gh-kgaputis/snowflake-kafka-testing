#!/bin/bash

# Check if jq is available
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to continue."
    exit 1
fi

# Check if a valid argument was passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <connector_name>"
    exit 1
fi

CONNECTOR_NAME="$1"

# Delete the connector
curl -X DELETE http://localhost:8083/connectors/"$CONNECTOR_NAME" | jq

# Check if the curl command was successful
if [ $? -eq 0 ]; then
    echo "Kafka Connect API call was successful (check output for errors)."
else
    echo "Failed to make API call to Kafka Connect."
    exit 4
fi