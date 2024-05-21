#!/bin/bash

echo "In entrypoint.sh"

# Check if connect-distributed.properties is a file
if [ ! -f "/opt/kafka/config/connect-distributed.properties" ]; then
    echo "Required file connect-distributed.properties is missing or not a file."
    exit 1
fi

# Continue with the normal startup process
exec "$@"
