# ============================================================================
# Stage 1: Download and verify Kafka, Snowflake connector, and optional
#           cloud-managed Kafka auth libraries.
# ============================================================================
FROM alpine:latest AS kafka_dist

ARG SCALA_VERSION=2.13
ARG KAFKA_VERSION=3.9.2
ARG KAFKA_DISTRO_BASE_URL=https://dlcdn.apache.org/kafka
# For old, very specific versions of Kafka, you may need to use the archive URL instead (very slow)
# ARG KAFKA_DISTRO_BASE_URL=https://archive.apache.org/dist/kafka

ARG SNOWFLAKE_CONNECTOR_VERSION=3.5.3
ARG BC_FIPS_VERSION=2.1.0
ARG BCPKIX_FIPS_VERSION=2.1.8

# Optional cloud-managed Kafka auth libraries (default: disabled)
ARG INCLUDE_AWS_IAM=false
ARG AWS_IAM_VERSION=2.3.5
ARG INCLUDE_GCP_IAM=false
ARG GCP_IAM_VERSION=1.0.6

ENV kafka_distro=kafka_$SCALA_VERSION-$KAFKA_VERSION.tgz
ENV kafka_distro_asc=$kafka_distro.asc

RUN apk add --no-cache gnupg unzip

WORKDIR /var/tmp

# Download and verify Kafka distribution
RUN wget -q $KAFKA_DISTRO_BASE_URL/$KAFKA_VERSION/$kafka_distro && \
    wget -q $KAFKA_DISTRO_BASE_URL/$KAFKA_VERSION/$kafka_distro_asc && \
    wget -q $KAFKA_DISTRO_BASE_URL/KEYS && \
    gpg --import KEYS && \
    gpg --verify $kafka_distro_asc $kafka_distro

RUN tar -xzf $kafka_distro && \
    rm -r kafka_$SCALA_VERSION-$KAFKA_VERSION/bin/windows

# Install Snowflake connector + BouncyCastle FIPS JARs in /opt/plugins
RUN mkdir -p /opt/plugins/snowflake-kafka-connector && \
    wget -q https://repo1.maven.org/maven2/com/snowflake/snowflake-kafka-connector/$SNOWFLAKE_CONNECTOR_VERSION/snowflake-kafka-connector-$SNOWFLAKE_CONNECTOR_VERSION.jar \
         -P /opt/plugins/snowflake-kafka-connector/ && \
    wget -q https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/$BC_FIPS_VERSION/bc-fips-$BC_FIPS_VERSION.jar \
         -P /opt/plugins/snowflake-kafka-connector/ && \
    wget -q https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-fips/$BCPKIX_FIPS_VERSION/bcpkix-fips-$BCPKIX_FIPS_VERSION.jar \
         -P /opt/plugins/snowflake-kafka-connector/

# /opt/auth-libs/ holds optional cloud auth JARs baked into the image.
# This is separate from /opt/extra-libs/ which is host-mounted via Docker Compose.
RUN mkdir -p /opt/auth-libs

# ---------- Optional: AWS MSK IAM auth (SASL/AWS_MSK_IAM) ----------
# Build with --build-arg INCLUDE_AWS_IAM=true to include.
# Downloads the uber-JAR from Maven Central (all dependencies bundled).
RUN if [ "$INCLUDE_AWS_IAM" = "true" ]; then \
      wget -q https://repo1.maven.org/maven2/software/amazon/msk/aws-msk-iam-auth/${AWS_IAM_VERSION}/aws-msk-iam-auth-${AWS_IAM_VERSION}-all.jar \
           -P /opt/auth-libs/; \
    fi

# ---------- Optional: GCP Managed Kafka auth (SASL/OAUTHBEARER) ----------
# Build with --build-arg INCLUDE_GCP_IAM=true to include.
# Uses Maven to resolve the handler's full transitive dependency tree,
# then dynamically strips any JAR already provided by the Kafka distribution.
# Maven + JDK are only installed when needed and are discarded with this
# throwaway build stage (only /opt/auth-libs/ is copied to the runtime image).
COPY docker/gcp-auth-deps.pom.xml /tmp/gcp-auth-deps.pom.xml
RUN if [ "$INCLUDE_GCP_IAM" = "true" ]; then \
      apk add --no-cache maven openjdk21-jdk && \
      mvn -f /tmp/gcp-auth-deps.pom.xml \
          dependency:copy-dependencies \
          -Dgcp.iam.version=${GCP_IAM_VERSION} \
          -DoutputDirectory=/tmp/gcp-all-deps \
          -DincludeScope=runtime \
          -q && \
      # Build set of artifact base-names already in the Kafka distribution
      for jar in /var/tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}/libs/*.jar; do \
        basename "$jar" | sed 's/-[0-9].*//' ; \
      done | sort -u > /tmp/kafka-provided.txt && \
      # Copy only JARs whose artifact name is NOT already provided by Kafka
      for jar in /tmp/gcp-all-deps/*.jar; do \
        base=$(basename "$jar" | sed 's/-[0-9].*//') && \
        if ! grep -qx "$base" /tmp/kafka-provided.txt; then \
          cp "$jar" /opt/auth-libs/ ; \
        fi ; \
      done && \
      rm -rf /tmp/gcp-all-deps /tmp/kafka-provided.txt ; \
    fi

# ============================================================================
# Stage 2: Runtime image
# ============================================================================
FROM azul/zulu-openjdk:21-latest

ARG SCALA_VERSION=2.13
ARG KAFKA_VERSION=3.9.2

ENV KAFKA_VERSION=$KAFKA_VERSION \
    SCALA_VERSION=$SCALA_VERSION \
    KAFKA_HOME=/opt/kafka

ENV PATH=${PATH}:${KAFKA_HOME}/bin

# Install runtime utilities in a single layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq && \
    rm -rf /var/lib/apt/lists/*

# Copy Kafka distribution
RUN mkdir ${KAFKA_HOME}
COPY --from=kafka_dist /var/tmp/kafka_$SCALA_VERSION-$KAFKA_VERSION ${KAFKA_HOME}
RUN chmod a+x ${KAFKA_HOME}/bin/*.sh

# Copy Snowflake connector plugin
COPY --from=kafka_dist /opt/plugins/snowflake-kafka-connector /opt/plugins/snowflake-kafka-connector

# Copy log4j configuration
COPY connect-log4j.properties ${KAFKA_HOME}/config/

# Create directories for host-mounted libs, plugins, and config
RUN mkdir -p /opt/extra-config /opt/extra-libs /opt/extra-plugins /opt/auth-libs
ENV CLASSPATH=/opt/extra-libs/*:/opt/auth-libs/*

# Copy cloud auth JARs (empty dir when both INCLUDE_*_AUTH are false)
COPY --from=kafka_dist /opt/auth-libs/ /opt/auth-libs/

# Entrypoint
COPY docker/entrypoint.sh docker/entrypoint_test.sh /docker/
RUN chmod +x /docker/entrypoint.sh /docker/entrypoint_test.sh

ENTRYPOINT ["/docker/entrypoint.sh"]
CMD ["/opt/kafka/bin/connect-distributed.sh", "/opt/kafka/config/connect-distributed.properties"]
