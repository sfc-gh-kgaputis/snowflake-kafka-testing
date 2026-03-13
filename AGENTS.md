# Agents Guide — Snowflake Kafka Testing

## Project Overview

This is a Docker-based local development and testing environment for the Snowflake Kafka Connector. It runs Apache Kafka Connect in distributed mode and sinks data into Snowflake via Snowpipe Streaming.

The project is **not** a library or application with source code to compile. It is an infrastructure/DevOps project composed of:

- A multi-stage `Dockerfile` that builds a Kafka Connect image with the Snowflake connector pre-installed
- `docker-compose.yml` with optional profiles for a local Kafka broker, Schema Registry, and Kafdrop UI
- Shell scripts for managing connectors via the Kafka Connect REST API
- JSON connector configuration templates with `envsubst` placeholders for credentials

## Key Technologies

- Apache Kafka Connect (distributed mode), Kafka 3.9.1, Scala 2.13
- Snowflake Kafka Connector (Snowpipe Streaming ingestion)
- Docker / Docker Compose
- Azul Zulu JDK 21
- Bash / `envsubst` / `jq` / `curl`

## Directory Layout

- `bin/` — Shell scripts that interact with the Kafka Connect REST API (create, update, check, delete, list connectors). All scripts expect `jq` and use `envsubst` for credential substitution.
- `connectors/` — Version-controlled connector JSON configs. These use `${SNOWFLAKE_*}` placeholders resolved at deploy time. Do not hard-code credentials here.
- `connectors-local/` — Gitignored local connector configs that may contain credentials.
- `docker/` — Container entrypoint scripts. `entrypoint.sh` handles three deployment modes: base64 env var (ECS/Fargate), mounted file (Docker Compose), or Kafka defaults. It also translates `CONNECT_*` env vars into worker property overrides.
- `extra-config/` — Host-mounted config files (e.g., Prometheus JMX exporter YAML). Mounted at `/opt/extra-config`.
- `extra-libs/` — Host-mounted JARs added to CLASSPATH (e.g., JMX agent, custom converters). Mounted at `/opt/extra-libs`.
- `extra-plugins/` — Host-mounted Kafka Connect plugins. Mounted at `/opt/extra-plugins` and included in `plugin.path`.
- `unversioned/` — Scratch/reference files. **Ignore this folder** — it is not part of the canonical project.

## Important Files

- `Dockerfile` — Two-stage multi-stage build: (1) `kafka_dist` (Alpine) downloads Kafka from Apache mirrors with GPG verification, installs the Snowflake connector + BouncyCastle FIPS JARs, and optionally downloads cloud-managed Kafka auth libraries (GCP and/or AWS) into `/opt/auth-libs/`; (2) runtime image (Azul Zulu JDK 21) copies everything in and sets up the CLASSPATH and entrypoint.
- `docker-compose.yml` — Defines `sf-kafka-connect` (always), plus `zookeeper`, `kafka`, `schema-registry` (profile: `kafka`), and `kafdrop` (profile: `kafdrop`).
- `.env.example` — Build args: `SCALA_VERSION`, `KAFKA_VERSION`, `SNOWFLAKE_CONNECTOR_VERSION`.
- `connect-distributed.properties.example` — Example Kafka Connect worker properties pointing to `kafka:9092` with `plugin.path=/opt/plugins,/opt/extra-plugins`.
- `connect-log4j.properties` — Log4j config with stdout appender and connector-context pattern. Snowflake connector and Ingest SDK loggers set to INFO.

## Conventions and Patterns

### Credential Management
All connector configs use `${SNOWFLAKE_HOST}`, `${SNOWFLAKE_USER}`, `${SNOWFLAKE_PRIVATE_KEY}`, `${SNOWFLAKE_PASSPHRASE}`, and `${SNOWFLAKE_ROLE}` placeholders. These are resolved by `envsubst` at deploy time from environment variables (sourced from `connect.env` or the shell). Never commit actual credentials.

### Connector Configurations
All connectors target `sfkafka_testing.raw` schema, use `SNOWPIPE_STREAMING` ingestion, and enable schematization. They share common buffer and streaming settings. Variations are in format (JSON, Avro, ByteArray/XML) and transforms (SMTs).

### Custom SMTs and Converters
Custom Single Message Transforms and converters are loaded from `extra-libs/` (CLASSPATH) or `extra-plugins/` (plugin path). Referenced classes include:
- `com.snowflake.examples.kafka.smt.ReshapeVehicleEvent`
- `com.snowflake.examples.kafka.smt.ParseXmlAsStrings`
- `com.snowflake.examples.kafka.smt.AddSchemaIdHeader`
- `com.snowflake.examples.kafka.converter.ByteArrayValueConverter`

### Environment Variable Overrides
The entrypoint converts any `CONNECT_*` env var to a Kafka Connect property by stripping the `CONNECT_` prefix, replacing `_` with `.`, and lowercasing. For example, `CONNECT_BOOTSTRAP_SERVERS=broker:9092` becomes `bootstrap.servers=broker:9092`.

### Cloud-Managed Kafka Authentication
The Dockerfile supports optional build-time inclusion of auth libraries for cloud-managed Kafka services, controlled by build args:

- **`INCLUDE_AWS_IAM=true`** — Downloads the AWS MSK IAM auth uber-JAR (`aws-msk-iam-auth-*-all.jar`) from Maven Central. Version controlled by `AWS_IAM_VERSION` (default `2.3.5`). Enables SASL/AWS_MSK_IAM with `software.amazon.msk.auth.iam.IAMLoginModule` and `software.amazon.msk.auth.iam.IAMClientCallbackHandler`.
- **`INCLUDE_GCP_IAM=true`** — Downloads the GCP Managed Kafka auth bundle (`managed-kafka-auth-login-handler` + transitive deps) from the `googleapis/managedkafka` GitHub releases. Version controlled by `GCP_IAM_VERSION` (default `1.0.6`). Enables SASL/OAUTHBEARER with `com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler`.

Auth JARs are placed in `/opt/auth-libs/` inside the image, which is on the CLASSPATH but **separate** from `/opt/extra-libs/` (host-mounted by Docker Compose for local development). Both are disabled by default.

## Working with This Project

### Adding a new connector
1. Create a new JSON file in `connectors/` following the existing pattern.
2. Use `${SNOWFLAKE_*}` placeholders for credentials.
3. Deploy with `bin/create_connector.sh connectors/<new_config>.json`.

### Adding a custom plugin or SMT
1. Place the JAR in `extra-plugins/` (for Kafka Connect plugin isolation) or `extra-libs/` (for CLASSPATH access).
2. Reference the class in your connector JSON config.
3. Restart the Kafka Connect container to pick up new JARs.

### Modifying the Docker image
- Kafka and connector versions are controlled by build args in `.env.example` / `.env`.
- The Dockerfile downloads Kafka from Apache mirrors and the Snowflake connector from Maven Central.
- BouncyCastle FIPS JARs are version-specific to the connector version (see comments in Dockerfile).
- Cloud auth libraries (AWS, GCP) are optional build args — see [Cloud-Managed Kafka Authentication](#cloud-managed-kafka-authentication) above. They use simple `wget` downloads (no Maven build stage) and land in `/opt/auth-libs/`.

### Testing
- Use `docker compose --profile kafka up` to run a local Kafka broker for end-to-end testing.
- Use `bin/list_all_connectors.sh` and `bin/check_connector.sh` to verify connector health.
- JMX metrics can be enabled with `JMX_REMOTE_INSECURE=1` for local debugging (port 1099).
