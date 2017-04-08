FROM alpine:latest

MAINTAINER ecoron

RUN echo "http://dl-3.alpinelinux.org/alpine/latest-stable/community/" >> /etc/apk/repositories &&\
        apk update && \
        apk add \
          openjdk8-jre-base \
          openssl \
          imagemagick \
          lsof \
          su-exec \
          bash \
          git \
          jq &&\
        rm -rf /var/cache/apk/*

RUN addgroup -g 1000 minecraft \
  && adduser -Ss /bin/false -u 1000 -G minecraft -h /home/minecraft minecraft \
  && mkdir /data \
  && mkdir /config \
  && mkdir /mods \
  && mkdir /plugins \
  && chown minecraft:minecraft /data /config /mods /plugins /home/minecraft

EXPOSE 25565 25575

COPY minecraft/start.sh /start
COPY minecraft/start-server.sh /start-minecraft

VOLUME ["/data","/mods","/config","/plugins","/home/minecraft"]
COPY minecraft/server.properties /tmp/server.properties
WORKDIR /data

ENTRYPOINT [ "/start" ]

ENV UID=1000 GID=1000 \
    MOTD="docker-minecraft-server by ecoron" \
    JVM_XX_OPTS="-XX:+UseG1GC" MAX_MEMORY="1G" \
    TYPE=VANILLA VERSION=LATEST FORGEVERSION=RECOMMENDED LEVEL=world PVP=true DIFFICULTY=easy \
    LEVEL_TYPE=DEFAULT GENERATOR_SETTINGS= WORLD= MODPACK= ONLINE_MODE=TRUE CONSOLE=true