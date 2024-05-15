# Snowflake Kafka Testing
This repo is designed to help with local development and testing of the Kafka Connector for Snowflake.  

**PLEASE NOTE:** This example project is not an official Snowflake offering. It comes with no support or warranty.
## Dependencies
- Docker
- Docker Compose

## Environment setup
Populate the required environment files:
- `.env`
- `connect.env`

In both cases, you will see an example file that ends with the suffix `.example`.

## Usage
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
