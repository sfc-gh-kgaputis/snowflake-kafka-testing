# Snowflake Kafka Testing

This repo is designed to help with local development and testing of the Kafka Connector for Snowflake. The project assumes that Kafka Connect will always run in "distributed mode", and includes several bash scripts to help deploy and undeploy connectors using the Kafka Connect REST API.

Using Docker Compose profiles, you can optionally enable a local Kafka Broker as well as the Kafdrop UI for 
observability into Kafka topics. 

**PLEASE NOTE:** This example project is not an official Snowflake offering. It comes with no support or warranty.

## Dependencies

- Docker
- Docker Compose
- bash (for commands below and helper shell scripts)
- envsubst (for setting dynamic values in connector JSON definitions)
- curl (for making API calls to Kafka Connect Rest API)
- jq (for parsing JSON responses)

## Environment setup

Populate the **required** environment and config files:

- `.env`: Used for setting Docker Compose build arg (e.g. the Kafka version to use). 
- `connect.env`: Use for setting environment variables in the Kafka Connect container. 
- `connect-distributed.properties`: Various config for Kafka Connect, including SASL authentication when connecting to secure Kafka clusters (e.g. Confluent Cloud).

These are not included in version control, because they will change for each user/environment.

In both cases, you will see an example file that ends with the suffix `.example`.

## Docker container management
### Set activate profile(s) for Docker Compose
This project uses the `COMPOSE_PROFILES` environment variable to optionally enable a local Kafka Broker and the Kafdrop UI. 

If you just want Kafka Connect (with the Snowflake Connector for Kafka), connecting to existing Kafka infrastructure, you can disregard this step.

To enable a local Kafka broker:
```
export COMPOSE_PROFILES=kafka
```
To enable a local Kafka broker and the Kafdrop UI:
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

### Populate required environment variables

```
export SNOWFLAKE_HOST="myorganization-myaccount.snowflakecomputing.com"
export SNOWFLAKE_USER="ingest"
export SNOWFLAKE_PRIVATE_KEY="REDACTED"
export SNOWFLAKE_PASSPHRASE="REDACTED"
export SNOWFLAKE_ROLE="ingest"
```

### Helper bash scripts for making API calls to Kafka Connect Rest API

### Create a connector

This bash script using `envsubst` to substitute environment variables (set above) in the JSON template for the
connector.

You can also hard code everything into the JSON definition, but be careful to avoid saving credentials (such as your
Snowflake private key) in version control.

```
bin/create_connector.sh connectors/snowflake_json_events.json
```

### List all connectors

```
bin/list_all_connectors.sh
```

### Check connector status

```
bin/check_connector.sh snowflake_json_events
```

### Delete a connector

```
bin/delete_connector.sh snowflake_json_events
```

## Maintenance

### Test entrypoint logic

```
docker build -t sf-kafka-connect .
docker run --entrypoint /docker/entrypoint_test.sh sf-kafka-connect sleep 1
```