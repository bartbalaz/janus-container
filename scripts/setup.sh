#!/bin/bash

echo "Step 1 - Installing the prerequisites"
apt update
apt install git
apt install -y build-essential

echo "Step 2 - Installing docker"
apt update
apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce docker-ce-cli containerd.io

echo "Step 3 - Installing the build requirements"
apt update
apt install -y python3-pip libmicrohttpd-dev libavutil-dev libavcodec-dev libavformat-dev libogg-dev libcurl4-openssl-dev libconfig-dev libjansson-dev libglib2.0-dev libssl-dev build-essential graphviz default-jdk flex bison cmake libtool automake liblua5.3-dev pkg-config gengetopt 
pip3 install meson
pip3 install ninja