# Start with a Ubuntu 20.04 image

FROM ubuntu:20.04

# First we need to add all the tools and components
RUN apt update && DEBIAN_FRONTEND="noninteractive" apt install -y tcpdump libmicrohttpd-dev libjansson-dev libssl-dev libsofia-sip-ua-dev libglib2.0-dev libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev libconfig-dev gengetopt libavutil-dev libavcodec-dev  libavformat-dev libavutil-dev libavcodec-dev libavformat-dev

ADD root/ /

ENTRYPOINT ["/janus/bin/janus", "-F", "/janus/etc/janus"]
