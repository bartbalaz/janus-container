#!/bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

if [ -z $IMAGE_TOOL ]; then
	IMAGE_TOOL="docker"
fi

echo
echo "Using $IMAGE_TOOL for building and managing images"

echo
echo " Step 1 - Installing the prerequisites and convenience packages "
echo "----------------------------------------------------------------"
echo
apt update
DEBIAN_FRONTEND="noninteractive" apt install -y apt-utils build-essential wget

echo
echo " Step 2 - Installing $IMAGE_TOOL "
echo "----------------------------"
echo
apt update
DEBIAN_FRONTEND="noninteractive" apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

if [ "$IMAGE_TOOL" == "docker" ]; then
	# Procedure from https://docs.docker.com/engine/install/ubuntu/
	
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt update
	DEBIAN_FRONTEND="noninteractive" apt install -y docker-ce docker-ce-cli containerd.io
else
	# Procedure from https://podman.io/getting-started/installation.html
	
	. /etc/os-release
	echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
	curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | apt-key add -
	apt update
	DEBIAN_FRONTEND="noninteractive" apt -y upgrade 
	DEBIAN_FRONTEND="noninteractive" apt -y install podman
fi

echo
echo " Step 3 - Installing the build requirements "
echo "--------------------------------------------"
echo
apt update
DEBIAN_FRONTEND="noninteractive" apt install -y python3-pip libmicrohttpd-dev libavutil-dev libavcodec-dev libavformat-dev libogg-dev libcurl4-openssl-dev libconfig-dev libjansson-dev libglib2.0-dev libssl-dev build-essential graphviz default-jdk flex bison cmake libtool automake liblua5.3-dev pkg-config gengetopt 
pip3 install meson
pip3 install ninja