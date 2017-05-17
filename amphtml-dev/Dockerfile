FROM node:latest

MAINTAINER ecoron

WORKDIR /home/amphtml
# COPY . /home/amphtml/
VOLUME ["/home/amphtml/"]

RUN cd /home/amphtml
RUN npm install -g gulp
RUN npm install gulp --save-dev
RUN npm link gulp

COPY build.sh /build
ENTRYPOINT [ "/build" ]

EXPOSE 8000