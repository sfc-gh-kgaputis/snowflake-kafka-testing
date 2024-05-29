#!/bin/bash

echo "** In entrypoint_test.sh"

# Path to connect-distributed.properties
properties_file="/opt/kafka/config/connect-distributed.properties"

# Mock environment variables
export CONNECT_BOOTSTRAP_SERVERS="kafka:9094"
export CONNECT_SASL_MECHANISM="PLAIN|123"
export CONNECT_NEW_PROPERTY="new_value"
# shellcheck disable=SC2016
export CONNECT_SPECIAL_CHARS_PROP='special \&|*?^$()[]'

# Prepare a sample properties file and environment
echo "bootstrap.servers=localhost:9092" > $properties_file
echo "sasl.mechanism=PLAIN" >> $properties_file

# Test the entrypoint script
ENTRYPOINT_TEST=1 source /docker/entrypoint.sh

# Check function
function check_property {
    key="$1"
    expected="$2"
    value=$(grep "^$key=" $properties_file | cut -d'=' -f2-)

    # Direct comparison, ensure both values are interpreted the same way
    if [[ "$value" == "$expected" ]]; then
        echo "PASS: $key is correctly set to $expected"
    else
        echo "FAIL: $key is set to $value instead of $expected"
    fi
}

# Run checks
check_property "bootstrap.servers" "$CONNECT_BOOTSTRAP_SERVERS"
check_property "sasl.mechanism" "$CONNECT_SASL_MECHANISM"
check_property "new.property" "$CONNECT_NEW_PROPERTY"
check_property "special.chars.prop" "$CONNECT_SPECIAL_CHARS_PROP"

echo "** Done with entrypoint_test.sh"
