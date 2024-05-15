#!/bin/bash

# Variables
host=localhost
port=8083

# Get list of connectors
connectors=$(curl -s -X GET http://$host:$port/connectors)

# Parse connectors from JSON response using jq tool
connectors=$(echo $connectors | jq -r '.[]')

# For each connector, send GET request to see details
for connector in $connectors
do
    echo "Getting connector: $connector"
    curl -X GET http://$host:$port/connectors/$connector/status | jq
done

