#!/bin/bash

echo "** In entrypoint.sh"

# Path to externally mounted properties, for Docker Compose use case
mounted_properties_file="/docker/connect-distributed-mounted.properties"
# Path to connect-distributed.properties used by Kafka Connect
target_properties_file="/opt/kafka/config/connect-distributed.properties"

if [[ -n "${CONNECT_DISTRIBUTED_PROPERTIES_BASE64}" ]]; then
    # If provided, write properties from base64 encoded env var
    echo "Decoding CONNECT_DISTRIBUTED_PROPERTIES_BASE64 into: $target_properties_file"
    echo "${CONNECT_DISTRIBUTED_PROPERTIES_BASE64}" | base64 --decode > $target_properties_file
    echo "Done writing connect-distributed.properties"
elif [ -f "$mounted_properties_file" ]; then
    # Fall back to properties file mounted via docker volume in special path
    cp -f "$mounted_properties_file" "$target_properties_file"
    echo "Externally mounted properties copied from $mounted_properties_file to $target_properties_file"
else
    # Otherwise use default properties from kafka
    echo "Using default connect-distributed.properties"
fi

# Ensure connect-distributed.properties is a file
if [ ! -f "$target_properties_file" ]; then
    echo "Required file connect-distributed.properties is missing or not a file."
    exit 1
fi

# Check if running in Fargate mode
if [[ -n "$FARGATE_MODE" ]]; then
    echo "Fargate mode detected. Fetching IP address from ECS metadata..."
    JSON=$(curl "${ECS_CONTAINER_METADATA_URI}/task")
    TASK_IP=$(echo "$JSON" | jq -r '.Containers[0].Networks[0].IPv4Addresses[0]')
    # Check if TASK_IP is not empty
    if [[ -n "$TASK_IP" ]]; then
        export CONNECT_REST_ADVERTISED_HOST_NAME=$TASK_IP
    else
        echo "Failed to retrieve IP address from metadata."
        exit 1
    fi
fi

# Check if the environment variable is not set
if [ -z "$CONNECT_REST_ADVERTISED_HOST_NAME" ]; then
    echo "Using runtime hostname for CONNECT_REST_ADVERTISED_HOST_NAME"
    export CONNECT_REST_ADVERTISED_HOST_NAME=$HOSTNAME
fi
echo "CONNECT_REST_ADVERTISED_HOST_NAME set to: $CONNECT_REST_ADVERTISED_HOST_NAME"

# Apply properties overrides given CONNECT_ prefixed env vars
while IFS='=' read -r name value; do
    if [[ $name == CONNECT_* ]]; then
        prop_name=$(echo "$name" | sed -e 's/^CONNECT_//' -e 's/_/./g' | tr '[:upper:]' '[:lower:]')
        echo "Overriding property: $prop_name"
        # Using awk to replace or append without regex affecting the value
        awk -v pname="$prop_name" -v pvalue="$value" -F'=' '
            BEGIN {found=0}
            {if ($1==pname) {print pname "=" pvalue; found=1} else {print $0}}
            END {if (!found) {print pname "=" pvalue}}
        ' "$target_properties_file" > temp && mv temp "$target_properties_file"
    fi
done < <(env)

# Enable insecure JMX remote monitoring (not for production)
if [ "$JMX_REMOTE_INSECURE" = "1" ]; then
    echo "Enabling JMX with insecure configuration."
    # Typically JMX advertised hostname should match Kafka Connect
    JMX_OPTS="-Dcom.sun.management.jmxremote \
              -Dcom.sun.management.jmxremote.port=1099 \
              -Dcom.sun.management.jmxremote.rmi.port=1099 \
              -Dcom.sun.management.jmxremote.local.only=false \
              -Dcom.sun.management.jmxremote.authenticate=false \
              -Dcom.sun.management.jmxremote.ssl=false \
              -Dcom.sun.management.jmxremote.host=0.0.0.0 \
              -Djava.rmi.server.hostname=${CONNECT_REST_ADVERTISED_HOST_NAME}"
    # Append JMX_OPTS to KAFKA_OPTS
    export KAFKA_OPTS="${KAFKA_OPTS} ${JMX_OPTS}"
fi

if [ "$ENTRYPOINT_TEST" = "1" ]; then
  echo "** ENTRYPOINT_TEST mode"
  "$@"
else
  # Continue with the normal startup process
  exec "$@"
fi
