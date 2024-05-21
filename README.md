# Snowflake Kafka Testing
This repo is designed to help with local development and testing of the Kafka Connector for Snowflake.  

**PLEASE NOTE:** This example project is not an official Snowflake offering. It comes with no support or warranty.
## Dependencies
- Docker
- Docker Compose
- bash (for commands below and helper shell scripts)
- envsubst (for setting dynamic values in connector JSON definitions)
- curl (for making API calls to Kafka Connect Rest API)
- jq (for parsing JSON responses)


## Environment setup
Populate the required environment and config files:
- `.env`
- `connect.env`
- `connect-distributed.properties`

These are not included in version control, because they will change for each user/environment. 

In both cases, you will see an example file that ends with the suffix `.example`.

## Docker container management
### Build Kafka Connect container with Snowflake connector
```
docker-compose build
```
### Start local Kafka environment
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
This bash script using `envsubst` to substitute environment variables (set above) in the JSON template for the connector.  

You can also hard code everything into the JSON definition, but be careful to avoid saving credentials (such as your Snowflake private key) in version control.

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