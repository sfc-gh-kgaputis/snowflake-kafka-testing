#!/bin/bash

echo "In entrypoint.sh"

# Check if the environment variable is set and not empty
if [[ ! -z "${CONNECT_DISTRIBUTED_PROPERTIES_BASE64}" ]]; then
    echo "Decoding CONNECT_DISTRIBUTED_PROPERTIES_BASE64 into: /opt/kafka/config/connect-distributed.properties"
    # Decode the Base64 content and write it to the connect-distributed.properties file
    echo "${CONNECT_DISTRIBUTED_PROPERTIES_BASE64}" | base64 --decode > /opt/kafka/config/connect-distributed.properties
    echo "Done writing connect-distributed.properties"
fi

# Check if connect-distributed.properties is a file
if [ ! -f "/opt/kafka/config/connect-distributed.properties" ]; then
    echo "Required file connect-distributed.properties is missing or not a file."
    exit 1
fi

# Continue with the normal startup process
exec "$@"
