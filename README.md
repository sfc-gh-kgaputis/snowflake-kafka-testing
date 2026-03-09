# Snowflake Kafka Testing

This repo is designed to help with local development and testing of the [Snowflake Kafka Connector](https://docs.snowflake.com/en/user-guide/kafka-connector). It builds a custom Docker image containing Apache Kafka Connect (distributed mode) with the Snowflake connector and Snowpipe Streaming pre-installed, and includes several bash scripts to deploy and manage connectors via the Kafka Connect REST API.

The Kafka Connect worker can connect to any external Kafka cluster (Confluent Cloud, Redpanda, Azure Event Hubs, etc.). Using Docker Compose profiles, you can also spin up a local Kafka broker, Schema Registry, and the Kafdrop UI for topic observability.

**PLEASE NOTE:** This example project is not an official Snowflake offering. It comes with no support or warranty.

## Dependencies

- Docker
- Docker Compose
- bash (for commands below and helper shell scripts)
- envsubst (from the `gettext` package — used to substitute `${SNOWFLAKE_*}` credential placeholders in connector JSON templates)
- curl (for making API calls to Kafka Connect REST API)
- jq (for parsing JSON responses)
- A Snowflake account with [key-pair authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth) configured

## Environment setup

Populate the **required** environment and config files:

- `.env`: Docker Compose build args — controls the Kafka version, Scala version, and Snowflake connector version. See `.env.example`.
- `connect.env`: Environment variables injected into the Kafka Connect container, including Snowflake credentials (`SNOWFLAKE_HOST`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY`, etc.). See `connect.env.example` if available.
- `connect-distributed.properties`: Kafka Connect worker configuration, including broker address and SASL authentication when connecting to secure Kafka clusters (e.g. Confluent Cloud). See `connect-distributed.properties.example`.

These are not included in version control, because they will change for each user/environment.

In each case, you will see an example file that ends with the suffix `.example`.

## Docker container management
### Set active profile(s) for Docker Compose
This project uses the `COMPOSE_PROFILES` environment variable to optionally enable a local Kafka broker, Schema Registry, and the Kafdrop UI. 

If you just want Kafka Connect (with the Snowflake connector), connecting to existing Kafka infrastructure, you can skip this step.

To enable a local Kafka broker and Schema Registry:
```
export COMPOSE_PROFILES=kafka
```
To also enable the Kafdrop web UI:
```
export COMPOSE_PROFILES=kafka,kafdrop
```

### Build Kafka Connect container with Snowflake connector

```
docker-compose build
```

### Start local Kafka Connect environment
```
docker-compose up -d
```

### Stop local Kafka environment
```
docker-compose stop
```

### Destroy local Kafka environment
```
docker-compose down --volumes
```

## Deploying a connector (distributed mode)
The following commands are based on shell scripts that wrap the API calls to the Kafka Connect REST API.   

### Helper bash scripts for making API calls to Kafka Connect REST API

All scripts live in `bin/` and require `jq`. The `create_connector.sh` and `update_connector.sh` scripts use `envsubst` to substitute `${SNOWFLAKE_*}` placeholders in the connector JSON templates before posting to the REST API.

### Create a connector

#### Populate required environment variables

```
export SNOWFLAKE_HOST="myorganization-myaccount.snowflakecomputing.com"
export SNOWFLAKE_USER="ingest"
export SNOWFLAKE_PRIVATE_KEY="REDACTED"
export SNOWFLAKE_PASSPHRASE="REDACTED"
export SNOWFLAKE_ROLE="ingest"
```

#### Create connector using bash script

This script uses `envsubst` to substitute environment variables (set above) in the JSON template for the
connector.

You can also hard code everything into the JSON definition, but be careful to avoid saving credentials (such as your
Snowflake private key) in version control.

Version-controlled connector configs are in `connectors/`. You can also create local configs in `connectors-local/` (gitignored) for experimentation.

```
bin/create_connector.sh connectors/snowflake_json_events.json
```

### Update a connector

```
bin/update_connector.sh connectors/snowflake_json_events.json
```

### List all connectors

```
bin/list_all_connectors.sh
```

### Check connector status
NOTE: The connector name is defined in the JSON definition.
```
bin/check_connector.sh snowflake_json_events
```

### Delete a connector
NOTE: The connector name is defined in the JSON definition.

```
bin/delete_connector.sh snowflake_json_events
```

### Remove all connectors

```
bin/remove_all_connectors.sh
```

## Included connector configurations

All connectors use Snowpipe Streaming ingestion with schematization enabled, targeting the `sfkafka_testing.raw` schema.

- `snowflake_json_events.json` — JSON events from the `events` topic (zstd compression, JMX metrics enabled)
- `snowflake_json_events_reshaped.json` — Same `events` topic, but applies a custom `ReshapeVehicleEvent` SMT and writes to the `reshaped_events` table
- `snowflake_avro_sensor_data.json` — Avro sensor data from the `sensor_data` topic via Schema Registry, with an `AddSchemaIdHeader` SMT
- `snowflake_xml_documents.json` — XML documents from the `xml_documents` topic using a ByteArray converter and `ParseXmlAsStrings` SMT (supports EBCDIC/Cp037 encoding)

## Extensibility

- **`extra-plugins/`** — Drop Kafka Connect plugin JARs here. They are mounted into the container and included in the plugin path.
- **`extra-libs/`** — Drop JARs here to add them to the container's CLASSPATH (useful for custom SMTs, converters, or the JMX Prometheus agent).
- **`extra-config/`** — Place config files here (e.g., Prometheus JMX exporter YAML). Mounted at `/opt/extra-config` in the container.

## Entrypoint

The Docker entrypoint (`docker/entrypoint.sh`) supports three property-loading strategies:

1. **Base64 environment variable** (`CONNECT_DISTRIBUTED_PROPERTIES_BASE64`) — for ECS/Fargate deployments
2. **Mounted file** — Docker volume mount of `connect-distributed.properties` (default for Docker Compose)
3. **Default** — Kafka distribution's built-in properties

Any `CONNECT_*` environment variable is automatically translated into a Kafka Connect worker property override (e.g., `CONNECT_BOOTSTRAP_SERVERS` becomes `bootstrap.servers`).

Set `JMX_REMOTE_INSECURE=1` to enable JMX remote access on port 1099 for local debugging. Set `FARGATE_MODE=1` for ECS task IP auto-discovery.

## Maintenance

### Test entrypoint logic

```
docker build -t sf-kafka-connect .
docker run --entrypoint /docker/entrypoint_test.sh sf-kafka-connect sleep 1
```