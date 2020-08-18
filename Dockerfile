# Start with a Ubuntu 20.04 image

FROM ubuntu:20.04

#EXPOSE 8088/tcp
#EXPOSE 8089/tcp
# EXPOSE 7088/tcp
#EXPOSE 7889/tcp

# First we need to add all the tools and components
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt install -y libmicrohttpd-dev libjansson-dev libssl-dev libsofia-sip-ua-dev libglib2.0-dev libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev libconfig-dev gengetopt libavutil-dev libavcodec-dev  libavformat-dev libavutil-dev libavcodec-dev libavformat-dev

ADD root/ /

ENTRYPOINT ["/janus/bin/janus", "-F", "/janus/etc/janus"]
