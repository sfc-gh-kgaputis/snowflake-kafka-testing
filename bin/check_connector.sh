#!/bin/bash

# Check if a valid argument was passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <connector_name>"
    exit 1
fi

CONNECTOR_NAME="$1"

# Check connector status
curl -X GET http://localhost:8083/connectors/"$CONNECTOR_NAME"/status | jq

# Check if the curl command was successful
if [ $? -eq 0 ]; then
    echo "Kafka Connect API call was successful (check output for errors)."
else
    echo "Failed to make API call to Kafka Connect."
    exit 4
fi