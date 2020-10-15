#!/bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

# JANUS_REPO - Repository to fetch Janus gatweay sources from (e.g. https://github.com/bartbalaz/janus-gateway.git)
# JANUS_VERSION - Version of the Janus gateway sources to checkout (e.g. v0.10.0)
# TARGET_IMAGE_NAME - Target image name (e.g. janus)
# TARGET_IMAGE_TAG - Target image version (e.g. 01) 
# IMAGE_TOOL - Tool for creating and managing the images either "podman" or "docker", defaults to "docker"
# IMAGE_REGISTRY - The registry to store the image at, by default not set
# IMAGE_REGISTRY_USER - The registry user, by default not set
# IMAGE_REGISTRY_PASSWORD - The registry password, by default not set

# This is the top directory inside the container where "staging" and "root" subdirectories will be created
TOP_DIR=/image

ROOT_DIR=$TOP_DIR/root
STAGING_DIR=$TOP_DIR/staging

JANUS_SRC_CONFIG_DIR=$TOP_DIR/janus_config
JANUS_SRC_HTML_DIR=$STAGING_DIR/janus/html

JANUS_DST_DIR=$ROOT_DIR/janus
JANUS_DST_HTML_DIR=$JANUS_DST_DIR/html
JANUS_DST_HTML_MOUNT_DIR=$ROOT_DIR/html
JANUS_DST_INCLUDE_DIR=$JANUS_DST_DIR/include
JANUS_DST_SHARE_DIR=$JANUS_DST_DIR/share
JANUS_DST_CONFIG_DIR=$JANUS_DST_DIR/etc/janus
JANUS_DST_HOST_CONFIG_DIR=$JANUS_DST_DIR/etc/janus_host
JANUS_DST_RECORDING_DIR=$JANUS_DST_DIR/bin/janus-recordings

CERTIFICATE_LINKS_DIR=$ROOT_DIR/etc/certs
CERTIFICATE_ARCHIVE_DIR=$ROOT_DIR/archive

START_SCRIPT_SRC=$TOP_DIR/start.sh
START_SCRIPT_DST=$ROOT_DIR/start.sh 

JANUS_CLONE_DIR=$STAGING_DIR/janus

# create_dir PATH
# Creates the required directory path if it does not exist
create_dir() {
	if [ ! -d "$1" ]; then
		mkdir -p $1
	fi
}

# purge_dir PATH
# Removes the directory if it exists
purge_dir() {
	if [ -d "$1" ]; then
		rm -rf $1
	fi
}

# test_parameter PARAMETER_NAME $PARAMETER_NAME [mandatory|optional]
# Tests a parameter, if the parameter is emty while mandatory, the script exits
test_parameter() {
	if [ "$3" != "mandatory" ] && [ "$3" != "optional" ]; then
		echo "Parameter $1 must either be mandatory or optional"
		exit 1
	elif [ -z "$2" ] && [ "$3" == "mandatory" ]; then
		echo "Mandatory parameter $1 emtpy"
		exit 1
	elif [ -z "$2" ]; then
		echo "Non-mandatory parameter $1 empty"
	else
		echo Parameter "$1 = $2"
	fi
}


# Main script starts here

echo
echo " Verifying parameters "
echo "----------------------"
test_parameter JANUS_REPO "$JANUS_REPO" optional
test_parameter JANUS_VERSION "$JANUS_VERSION" optional
test_parameter TARGET_IMAGE_NAME "$TARGET_IMAGE_NAME" optional
test_parameter TARGET_IMAGE_TAG "$TARGET_IMAGE_TAG" optional
test_parameter IMAGE_TOOL "$IMAGE_TOOL" optional
test_parameter IMAGE_REGISTRY "$IMAGE_REGISTRY" optional
test_parameter IMAGE_REGISTRY_USER "$IMAGE_REGISTRY_USER" optional
test_parameter IMAGE_REGISTRY_PASSWORD "$IMAGE_REGISTRY_PASSWORD" optional

# Set the default values

if [ -z $TARGET_IMAGE_NAME ]; then
	TARGET_IMAGE_NAME="janus"
	echo Parameter TARGET_IMAGE_NAME set to "$TARGET_IMAGE_NAME"
fi

if [ -z $TARGET_IMAGE_TAG ]; then
	TARGET_IMAGE_TAG="latest"
	echo Parameter TARGET_IMAGE_TAG set to "$TARGET_IMAGE_TAG"
fi

if [ -z $IMAGE_TOOL ]; then
	IMAGE_TOOL="docker"
fi

echo
echo "Using $IMAGE_TOOL for building and managing images"

if [ ! -z $IMAGE_REGISTRY ]; then
	FULL_TARGET_IMAGE_NAME=$IMAGE_REGISTRY/$TARGET_IMAGE_NAME:$TARGET_IMAGE_TAG
else
	FULL_TARGET_IMAGE_NAME=$TARGET_IMAGE_NAME:$TARGET_IMAGE_TAG
fi

echo
echo " Creating root and staging directories "
echo "---------------------------------------"
create_dir $ROOT_DIR
create_dir $STAGING_DIR

echo
echo " Installing libnice (latest avaialble version) "
echo "-----------------------------------------------"
cd $STAGING_DIR
git clone https://gitlab.freedesktop.org/libnice/libnice
cd libnice
meson --prefix=$ROOT_DIR/usr build && ninja -C build &&  ninja -C build install 

echo
echo " Installing libsrtp-2.2.0 "
echo "--------------------------"
cd $STAGING_DIR
wget https://github.com/cisco/libsrtp/archive/v2.2.0.tar.gz
tar xfv v2.2.0.tar.gz
cd libsrtp-2.2.0
./configure --prefix=$ROOT_DIR/usr --enable-openssl
make shared_library && make install

echo
echo " Building janus-gateway "
echo "--------------------------"
cd $STAGING_DIR
if [ -z "$JANUS_REPO" ]
then 
	echo "Cloning from default repo to $JANUS_CLONE_DIR"
	git clone https://github.com/meetecho/janus-gateway.git $JANUS_CLONE_DIR
else
	echo "Cloning from $JANUS_REPO to $JANUS_CLONE_DIR"
	git clone $JANUS_REPO $JANUS_CLONE_DIR
fi
cd $JANUS_CLONE_DIR
[ ! -z "$JANUS_VERSION" ] && git checkout $JANUS_VERSION
/bin/bash $(pwd)/autogen.sh

export PKG_CONFIG_PATH=$ROOT_DIR/usr/lib/pkgconfig:$ROOT_DIR/usr/lib/x86_64-linux-gnu/pkgconfig 
/bin/bash $(pwd)/configure --prefix=$JANUS_DST_DIR CFLAGS=-I$ROOT_DIR/usr/include 
 
make
make install
make configs 

echo
echo " Removing include and share directories "
echo "----------------------------------------"
purge_dir $JANUS_DST_INCLUDE_DIR
purge_dir $JANUS_DST_SHARE_DIR

echo
echo " Removing default configuration "
echo "--------------------------------"
purge_dir $JANUS_DST_CONFIG_DIR

echo
echo " Crating host configuration directory "
echo "--------------------------------------"
create_dir $JANUS_DST_HOST_CONFIG_DIR

echo
echo " Copying custom configuration "
echo "------------------------------"
create_dir $JANUS_DST_CONFIG_DIR
cp $JANUS_SRC_CONFIG_DIR/* $JANUS_DST_CONFIG_DIR

echo
echo " Copying the Janus HTML examples "
echo "---------------------------------"
create_dir $JANUS_DST_HTML_DIR
create_dir $JANUS_DST_HTML_MOUNT_DIR
cp -R $JANUS_SRC_HTML_DIR/* $JANUS_DST_HTML_DIR

echo
echo " Creating directory for mounting the certbot certificates "
echo "----------------------------------------------------------"
create_dir $CERTIFICATE_LINKS_DIR
create_dir $CERTIFICATE_ARCHIVE_DIR

echo
echo " Creating directory for saving the recordings "
echo "----------------------------------------------"
create_dir $JANUS_DST_RECORDING_DIR

echo
echo " Copying the startup script into the root directory "
echo "----------------------------------------------------"
cp $START_SCRIPT_SRC $START_SCRIPT_DST
chmod a+x $START_SCRIPT_DST

echo
echo " Building the Janus gateway target image "
echo "-----------------------------------------"
cd $TOP_DIR
$IMAGE_TOOL build -t $FULL_TARGET_IMAGE_NAME -f Dockerfile.exec .

if [ ! -z $IMAGE_REGISTRY ]; then 
	# We need to push the image to registry

	echo 
	echo "Pushing image to registry $IMAGE_REGISTRY"
	echo "----------------------------------------------"
	if [ "$IMAGE_TOOL" == "docker" ]; then
		$IMAGE_TOOL login -u $IMAGE_REGISTRY_USER -p $IMAGE_REGISTRY_PASSWORD $IMAGE_REGISTRY
		$IMAGE_TOOL push $FULL_TARGET_IMAGE_NAME
		$IMAGE_TOOL logout $IMAGE_REGISTRY
	else
		$IMAGE_TOOL push --creds $IMAGE_REGISTRY_USER:$IMAGE_REGISTRY_PASSWORD $FULL_TARGET_IMAGE_NAME
	fi
fi
