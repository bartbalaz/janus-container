#!/bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo


# Environment variables
#
# IMAGE_TOOL - Tool for creating and managing the images either "podman", "docker" or "external", defaults to "docker"
# CI_COMMIT_TAG - Current commit tag set by GitLab CI

if [ -z $CI_COMMIT_TAG ]; then
	CI_COMMIT_TAG="none"
	echo
	echo Parameter CI_COMMIT_TAG set to "$CI_COMMIT_TAG"
fi

if [ -z $IMAGE_TOOL ]; then
	IMAGE_TOOL="docker"
	echo
	echo Parameter IMAGE_TOOL set to "$IMAGE_TOOL"
fi

# This is the top directory inside the container
TOP_DIR=/

# The build info file provides some additional information about the image build
BUILD_INFO_FILE=$ROOT_DIR/build.info

echo
echo "Using $IMAGE_TOOL for building and managing images"

echo 
echo " Opening the build information file: $BUILD_INFO_FILE "
echo "------------------------------------------------------"

echo "-------------- BUILD IMAGE INFO ---------------------" >> $BUILD_INFO_FILE
echo "Build image information data" >> $BUILD_INFO_FILE
echo "Build started at $(date)" >> $BUILD_INFO_FILE
echo "Build image version: $CI_COMMIT_TAG" >> $BUILD_INFO_FILE
echo "Build image tool: $IMAGE_TOOL" >> $BUILD_INFO_FILE

echo
echo " Step 1 - Installing the prerequisites and convenience packages "
echo "----------------------------------------------------------------"
echo
apt update
DEBIAN_FRONTEND="noninteractive" apt install -y apt-utils build-essential wget git 

if [ "$IMAGE_TOOL" != "external" ]; then 
	# NOTE: Currently it is impossible to create the target image using Podman hence we install docker unless IMAGE_TOOL is set to "external"
	echo
	echo " Step 2a - Installing Docker "
	echo "-----------------------------"
	echo
	apt update
	DEBIAN_FRONTEND="noninteractive" apt install -y apt-transport-https curl ca-certificates gnupg-agent software-properties-common

	# Procedure from https://docs.docker.com/engine/install/ubuntu/

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt update
	DEBIAN_FRONTEND="noninteractive" apt install -y docker-ce docker-ce-cli containerd.io
		
	if [ "$IMAGE_TOOL" == "podman" ]; then
		echo
		echo " Step 2b - Installing Podman "
		echo "-----------------------------"
		echo

		# Procedure from https://podman.io/getting-started/installation.html
		
		. /etc/os-release
		echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
		curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | apt-key add -
		apt update
		DEBIAN_FRONTEND="noninteractive" apt -y upgrade 
		DEBIAN_FRONTEND="noninteractive" apt -y install podman
	fi
else
	echo
	echo " Step 2 - Skipping installation of Docker "
	echo "------------------------------------------"
fi 

echo
echo " Step 3 - Installing the build requirements "
echo "--------------------------------------------"
echo
apt update
DEBIAN_FRONTEND="noninteractive" apt install -y python3-pip libmicrohttpd-dev libavutil-dev libavcodec-dev libavformat-dev libogg-dev libcurl4-openssl-dev libconfig-dev libjansson-dev libglib2.0-dev libssl-dev build-essential graphviz default-jdk flex bison cmake libtool automake liblua5.3-dev pkg-config gengetopt 
pip3 install meson
pip3 install ninja

echo "Build finished at $(date)" >> $BUILD_INFO_FILE
echo "-----------------------------------------------------" >> $BUILD_INFO_FILE

