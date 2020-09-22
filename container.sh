#!/bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

# Configuration - Set these parameters to the appropriate values, we suggest to create a configuration file with 
# a set of export statements that is "source'd" before the execution of this script

# JANUS_REPO - Repository to fetch Janus gatweay sources from (e.g. https://github.com/bartbalaz/janus-gateway.git)
# JANUS_VERSION - Version of the Janus gateway sources to checkout (e.g. v0.10.0)
# TARGET_IMAGE_NAME - Target Janus gateway image name (e.g. janus)
# TARGET_IMAGE_VERSION - Target Janus gateway image version (e.g. 01) 
# BUILD_IMAGE_NAME - Name of the build image allowing to build the Janus gateway image
# BUILD_IMAGE_VERSION - Version of the build image allowing to build the Janus gateway image
# SKIP_BUILD_IMAGE - When set to 'true', the build image will not be created, the available build image will be used to create the tarteg image
# SKIP_TARGET_IMAGE - When set to 'true', the target image will not be created.
# USE_HOST_CONFIG_DIR - When set to 'true' the build image will mount the host Janus configuration directory instead of using the one that was copied
# during the build image creation
# HOST_NAME - Name of the host including the fqdn (e.g. <host>.<domain>), please note that it may be difficult 
# to universally automate this parameter (e.g. by using 'hostname' command) because of the variety of
# environments where the returned values may not be appropriate 

# Global variables - Should not need to be modified
TOP_DIR=$(pwd)
JANUS_SRC_CONFIG_DIR=$TOP_DIR/janus_config

FULL_BUILD_IMAGE_NAME=$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION
FULL_TARGET_IMAGE_NAME=$TARGET_IMAGE_NAME:$TARGET_IMAGE_VERSION

# test_parameter PARAMETER_NAME $PARAMETER_NAME [mandatory|optional]
test_parameter() {
	if [ -z "$2" ] && [ "$3" == "mandatory" ]; then
		echo "Mandatory parameter $1 emtpy"
		exit 1
	elif [ -z "$2" ]; then
		echo "Non-mandatory parameter $1 empty"
	else
		echo Parameter "$1 = $2"
	fi
}

# The buld image creation process requires only the image name and tag
if [ "$SKIP_BUILD_IMAGE" == 'true' ]; then
	echo
	echo " Skipping build image creation "
	echo "-------------------------------"
else
	echo
	echo " Creating the build image "
	echo "--------------------------"
	test_parameter BUILD_IMAGE_NAME $BUILD_IMAGE_NAME mandatory
	test_parameter BUILD_IMAGE_VERSION $BUILD_IMAGE_VERSION mandatory

	docker build -t $FULL_BUILD_IMAGE_NAME -f Dockerfile.build . 
fi

# The target image creation requires the build image name and tag, the target image name and tag 
# and optionally the version of Janus gatweay sources
if [ "$SKIP_TARGET_IMAGE" == "true" ]; then
	echo
	echo " Skipping target image creation "
	echo "--------------------------------"
	
else
	echo
	echo " Executing the build image to create the target image "
	echo "------------------------------------------------------"
	test_parameter JANUS_REPO $JANUS_REPO optional
	test_parameter JANUS_VERSION $JANUS_VERSION optional
	test_parameter TARGET_IMAGE_NAME $TARGET_IMAGE_NAME mandatory
	test_parameter TARGET_IMAGE_VERSION $TARGET_IMAGE_VERSION mandatory
	test_parameter BUILD_IMAGE_NAME $BUILD_IMAGE_NAME mandatory
	test_parameter BUILD_IMAGE_VERSION $BUILD_IMAGE_VERSION mandatory
	test_parameter USE_HOST_CONFIG_DIR $USE_HOST_CONFIG_DIR optional

	if [ "$USE_HOST_CONFIG_DIR" == 'true' ]; then
		echo
		echo "Using Janus gateway configuration from host folder $JANUS_SRC_CONFIG_DIR"
		CONFIG_DIR_MOUNT="-v $JANUS_SRC_CONFIG_DIR:/image/janus_config"
	else
		echo
		echo "Using Janus gateway configuration from build image (copied during the build image creation)"
		CONFIG_DIR_MOUNT=""
	fi
	
	docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock $CONFIG_DIR_MOUNT \
	-e "JANUS_REPO=$JANUS_REPO" \
	-e "JANUS_VERSION=$JANUS_VERSION" \
	-e "TARGET_IMAGE_NAME=$TARGET_IMAGE_NAME" \
	-e "TARGET_IMAGE_VERSION=$TARGET_IMAGE_VERSION" \
	-e "HOST_NAME=$HOST_NAME" \
	$FULL_BUILD_IMAGE_NAME
	
	echo
	echo "To execute the Janus gateway target image non-interactively issue the following command: "
	echo "docker run --rm -d -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive -v /var/janus/recordings:/janus/bin/janus-recordings $FULL_TARGET_IMAGE_NAME"
	echo
	echo "To execute the Janus gateway target image interactively issue the following command: "
	echo "docker run --rm -it -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive -v /var/janus/recordings:/janus/bin/janus-recordings $FULL_TARGET_IMAGE_NAME"
	echo
	echo "Notes: "
	echo "- To provide custom Janus gateway configuraiton from a <Janus config host folder> to the target image, add the following parameter before the image name: -v <Janus config host folder absolute path>:/janus/etc/janus"
fi





