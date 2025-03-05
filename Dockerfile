FROM alpine:latest AS kafka_dist

ARG SCALA_VERSION=2.13
ARG KAFKA_VERSION=3.9.0
ARG KAFKA_DISTRO_BASE_URL=https://dlcdn.apache.org/kafka
ARG SNOWFLAKE_CONNECTOR_VERSION=2.5.0

ENV kafka_distro=kafka_$SCALA_VERSION-$KAFKA_VERSION.tgz
ENV kafka_distro_asc=$kafka_distro.asc

RUN apk add --no-cache gnupg gnupg-keyboxd

WORKDIR /var/tmp

RUN wget -q $KAFKA_DISTRO_BASE_URL/$KAFKA_VERSION/$kafka_distro
RUN wget -q $KAFKA_DISTRO_BASE_URL/$KAFKA_VERSION/$kafka_distro_asc
RUN wget -q $KAFKA_DISTRO_BASE_URL/KEYS

RUN gpg --import KEYS
RUN gpg --verify $kafka_distro_asc $kafka_distro

RUN tar -xzf $kafka_distro 
RUN rm -r kafka_$SCALA_VERSION-$KAFKA_VERSION/bin/windows

# Install Snowflake connector in /opt/plugins
RUN mkdir -p /opt/plugins/snowflake-kafka-connector
RUN wget https://repo1.maven.org/maven2/com/snowflake/snowflake-kafka-connector/$SNOWFLAKE_CONNECTOR_VERSION/snowflake-kafka-connector-$SNOWFLAKE_CONNECTOR_VERSION.jar -P /opt/plugins/snowflake-kafka-connector/
RUN wget https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/1.0.2.4/bc-fips-1.0.2.4.jar -P /opt/plugins/snowflake-kafka-connector/
RUN wget https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-fips/1.0.3/bcpkix-fips-1.0.3.jar -P /opt/plugins/snowflake-kafka-connector/

FROM azul/zulu-openjdk:17-latest

# Install any necessary utilities in one layer to keep the image clean and optimized
RUN apt-get update && \
    apt-get install -y \
    jq \
    # any other packages you might need
    && rm -rf /var/lib/apt/lists/*

ARG SCALA_VERSION=2.13
ARG KAFKA_VERSION=3.9.0

ENV KAFKA_VERSION=$KAFKA_VERSION \
    SCALA_VERSION=$SCALA_VERSION \
    KAFKA_HOME=/opt/kafka

ENV PATH=${PATH}:${KAFKA_HOME}/bin

RUN mkdir ${KAFKA_HOME} && apt-get update && apt-get install curl -y && apt-get clean

COPY --from=kafka_dist /var/tmp/kafka_$SCALA_VERSION-$KAFKA_VERSION ${KAFKA_HOME}

RUN mkdir -p /opt/plugins/snowflake-kafka-connector
COPY --from=kafka_dist /opt/plugins/snowflake-kafka-connector /opt/plugins/snowflake-kafka-connector

RUN echo $pwd

COPY connect-log4j.properties ${KAFKA_HOME}/config/

RUN chmod a+x ${KAFKA_HOME}/bin/*.sh

# Create additional folders for libs and plugins mounted from host file system
RUN mkdir -p /opt/extra-config
RUN mkdir -p /opt/extra-libs
RUN mkdir -p /opt/extra-plugins
ENV CLASSPATH=${CLASSPATH}:/opt/extra-libs/*

RUN mkdir -p /docker
COPY docker/entrypoint.sh /docker/entrypoint.sh
COPY docker/entrypoint_test.sh /docker/entrypoint_test.sh
RUN chmod +x /docker/entrypoint.sh
RUN chmod +x /docker/entrypoint_test.sh

ENTRYPOINT ["/docker/entrypoint.sh"]
CMD ["/opt/kafka/bin/connect-distributed.sh", "/opt/kafka/config/connect-distributed.properties"]