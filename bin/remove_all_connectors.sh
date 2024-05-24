#!/bin/bash

# Check if jq is available
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq to continue."
    exit 1
fi

# Variables
host=localhost
port=8083

# Get list of connectors
connectors=$(curl -s -X GET http://$host:$port/connectors)

# Parse connectors from JSON response using jq tool
connectors=$(echo $connectors | jq -r '.[]')

# For each connector, send DELETE request to remove it
for connector in $connectors
do
    echo "Deleting connector: $connector"
    curl -X DELETE http://$host:$port/connectors/$connector
done
