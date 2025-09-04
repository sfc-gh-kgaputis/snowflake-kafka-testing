#!/bin/bash

# Script to create and run Kafka Connect standalone connectors from templated properties files
# Usage: ./create_standalone_connectors.sh <kafka_bin_path> <connect_standalone_properties> <connector1.properties> [connector2.properties] ...

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 <kafka_bin_path> <connect_standalone_properties> <connector1.properties> [connector2.properties] ..."
    echo ""
    echo "Arguments:"
    echo "  kafka_bin_path                Path to Kafka bin directory (e.g., /opt/kafka/bin)"
    echo "  connect_standalone_properties Path to the Kafka Connect standalone configuration file"
    echo "  connector.properties          One or more connector configuration files (templated)"
    echo ""
    echo "Example:"
    echo "  $0 /opt/kafka/bin connect-standalone.properties sink1.properties sink2.properties"
    exit 1
}

# Check dependencies
if ! command -v envsubst &> /dev/null; then
    echo "Error: envsubst not found. Please install gettext package."
    exit 1
fi

# Check arguments
if [ "$#" -lt 3 ]; then
    echo "Error: At least 3 arguments required."
    usage
fi

# Parse arguments
KAFKA_BIN_PATH="$1"
CONNECT_STANDALONE_PROPS="$2"
shift 2
CONNECTOR_PROPS=("$@")

# Validate Kafka bin path
if [ ! -d "$KAFKA_BIN_PATH" ]; then
    echo "Error: Kafka bin directory '$KAFKA_BIN_PATH' not found."
    exit 2
fi

CONNECT_SCRIPT="$KAFKA_BIN_PATH/connect-standalone.sh"
if [ ! -x "$CONNECT_SCRIPT" ]; then
    echo "Error: connect-standalone.sh not found or not executable at '$CONNECT_SCRIPT'"
    exit 2
fi

# Validate files exist
for file in "$CONNECT_STANDALONE_PROPS" "${CONNECTOR_PROPS[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found."
        exit 2
    fi
done

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "Cleaning up '$TEMP_DIR'..."
        rm -rf "$TEMP_DIR"
    fi
}

# Create temporary directory
TEMP_DIR=$(mktemp -d -t kafka-connect-XXXXXX)
trap cleanup EXIT INT TERM

echo "Using temporary directory: $TEMP_DIR"
echo "Processing configuration files..."

# Process standalone properties
PROCESSED_STANDALONE="$TEMP_DIR/connect-standalone.properties"
if ! envsubst < "$CONNECT_STANDALONE_PROPS" > "$PROCESSED_STANDALONE"; then
    echo "Error: Failed to process '$CONNECT_STANDALONE_PROPS'"
    exit 3
fi

# Process connector properties
PROCESSED_CONNECTORS=()
for i in "${!CONNECTOR_PROPS[@]}"; do
    connector="${CONNECTOR_PROPS[$i]}"
    processed="$TEMP_DIR/connector-$((i+1)).properties"

    if ! envsubst < "$connector" > "$processed"; then
        echo "Error: Failed to process '$connector'"
        exit 3
    fi

    PROCESSED_CONNECTORS+=("$processed")
    echo "  $(basename "$connector") -> $processed"
done

echo "Standalone config: $PROCESSED_STANDALONE"
echo "Starting Kafka Connect standalone..."

# Build and execute command
"$CONNECT_SCRIPT" "$PROCESSED_STANDALONE" "${PROCESSED_CONNECTORS[@]}"