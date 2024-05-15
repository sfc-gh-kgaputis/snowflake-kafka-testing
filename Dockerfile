FROM alpine:latest AS kafka_dist

ARG SCALA_VERSION
ARG KAFKA_VERSION
ARG KAFKA_DISTRO_BASE_URL=https://dlcdn.apache.org/kafka

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

RUN wget https://repo1.maven.org/maven2/com/snowflake/snowflake-kafka-connector/2.2.2/snowflake-kafka-connector-2.2.2.jar -P kafka_$SCALA_VERSION-$KAFKA_VERSION/libs/
RUN wget https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/1.0.2.4/bc-fips-1.0.2.4.jar -P kafka_$SCALA_VERSION-$KAFKA_VERSION/libs/
RUN wget https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-fips/1.0.3/bcpkix-fips-1.0.3.jar -P kafka_$SCALA_VERSION-$KAFKA_VERSION/libs/

FROM openjdk:11-jre-slim

ARG SCALA_VERSION
ARG KAFKA_VERSION

ENV KAFKA_VERSION=$KAFKA_VERSION \
    SCALA_VERSION=$SCALA_VERSION \
    KAFKA_HOME=/opt/kafka

ENV PATH=${PATH}:${KAFKA_HOME}/bin

RUN mkdir ${KAFKA_HOME} && apt-get update && apt-get install curl -y && apt-get clean

COPY --from=kafka_dist /var/tmp/kafka_$SCALA_VERSION-$KAFKA_VERSION ${KAFKA_HOME}

RUN echo $pwd

COPY connect-distributed.properties ${KAFKA_HOME}/config/
COPY connect-log4j.properties ${KAFKA_HOME}/config/

#COPY connect_lib/*  ${KAFKA_HOME}/libs/

RUN chmod a+x ${KAFKA_HOME}/bin/*.sh

RUN mkdir -p /opt/plugins

CMD ["/opt/kafka/bin/connect-distributed.sh", "/opt/kafka/config/connect-distributed.properties"]