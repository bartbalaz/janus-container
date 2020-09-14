FROM ubuntu:18.04

# API secure ports only 
EXPOSE 8089/tcp 7889/tcp

# First we need to add all the tools and components
# RUN apt update && DEBIAN_FRONTEND="noninteractive" apt install -y libmicrohttpd-dev libjansson-dev libssl-dev libsofia-sip-ua-dev libglib2.0-dev libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev libconfig-dev gengetopt libavutil-dev libavcodec-dev libavformat-dev

ADD root/ /

# ENTRYPOINT ["/start.sh"]
