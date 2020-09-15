#!/bin/bash

# This script cretes the Janus build image.
# This script isntalls Docker binaries but uses the host docker engine via the docker socket
# by running: docker run -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock

# Step 1 -  Install the basic pre-requisites
apt install git
apt install build-essential

# Step 2 - Install docker
apt update
apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce docker-ce-cli containerd.io

# Step 3 - Install buld requirements
apt update
apt install -y python3-pip libmicrohttpd-dev libavutil-dev libavcodec-dev libavformat-dev libogg-dev libcurl4-openssl-dev libconfig-dev libjansson-dev libglib2.0-dev libssl-dev build-essential graphviz default-jdk flex bison cmake libtool automake liblua5.3-dev pkg-config gengetopt 
pip3 install meson
pip3 install ninja