#!/bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

# Configuration - Set these parameters (environment variables) to the appropriate values prior to executing this script. 

# JANUS_REPO - Repository to fetch Janus gatweay sources from, defaults to https://github.com/bartbalaz/janus-gateway.git
# JANUS_VERSION - Version of the Janus gateway sources to checkout (e.g. v0.10.0), not set by default, the latest version of the maser branch will be used
# TARGET_IMAGE_NAME - Target Janus gateway image name, defaults to "janus"
# TARGET_IMAGE_VERSION - Target Janus gateway image version, defaults to "latest"
# BUILD_IMAGE_NAME - Name of the build image allowing to build the Janus gateway image, defaults to "janus_build"
# BUILD_IMAGE_VERSION - Version of the build image allowing to build the Janus gateway image, defaults to "latests"
# SKIP_BUILD_IMAGE - When set to "true", the build image will not be created, the available build image will be used to create the target image, by default not set
# SKIP_TARGET_IMAGE - When set to "true", the target image will not be created, by default not set
# BUILD_WITH_HOST_CONFIG_DIR - When set to "true" the build image will mount the host Janus configuration directory instead of using the one that was copied during the build image creation, by dfault not set
# RUN_WITH_HOST_CONFIGURATION_DIR - When set to "true" the image execution command displayed at the end of the sucessful build will show an option to use host Janus server configuration directory 
# i.e. <clone directory>/janus-config) instead of the embedded configuration during the target image creation process
# HOST_NAME - Name of the host (e.g. <host>.<domain>), please note that it may be difficult 
# to universally automate this parameter (e.g. by using 'hostname' command) because of the variety of
# environments where the returned values may not be appropriate 

# Global variables - Should not need to be modified
TOP_DIR=$(pwd)
JANUS_SRC_CONFIG_DIR=$TOP_DIR/janus_config

# test_parameter PARAMETER_NAME $PARAMETER_NAME [mandatory|optional]
# Verfies if the parameter is configured, if not while it is mandatory the script exits
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

# First step: Create the build image
if [ "$SKIP_BUILD_IMAGE" == "true" ]; then
	echo
	echo " Skipping build image creation "
	echo "-------------------------------"
else
	echo
	echo " Creating the build image "
	echo "--------------------------"
	
	# All the parameters are optional
	test_parameter BUILD_IMAGE_NAME "$BUILD_IMAGE_NAME" optional
	test_parameter BUILD_IMAGE_VERSION "$BUILD_IMAGE_VERSION" optional

	# The empty parameters are configured with default values
	if [ -z $BUILD_IMAGE_NAME ]; then
		BUILD_IMAGE_NAME="janus_build"
		echo Parameter BUILD_IMAGE_NAME set to "$BUILD_IMAGE_NAME"
	fi

	if [ -z $BUILD_IMAGE_VERSION ]; then
		BUILD_IMAGE_VERSION="latest"
		echo Parameter BUILD_IMAGE_VERSION set to "$BUILD_IMAGE_VERSION"
	fi

	FULL_BUILD_IMAGE_NAME=$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION

	# Create the build image
	docker build -t $FULL_BUILD_IMAGE_NAME -f Dockerfile.build . 
fi

# Second step: Create the target image
# The build image must exist to run this step while skipping the first one.
if [ "$SKIP_TARGET_IMAGE" == "true" ]; then
	echo
	echo " Skipping target image creation "
	echo "--------------------------------"
	
else
	echo
	echo " Executing the build image to create the target image "
	echo "------------------------------------------------------"
	
	# All parameters are optional
	test_parameter HOST_NAME "$HOST_NAME" optional
	test_parameter JANUS_REPO "$JANUS_REPO" optional
	test_parameter JANUS_VERSION "$JANUS_VERSION" optional
	test_parameter TARGET_IMAGE_NAME "$TARGET_IMAGE_NAME" optional
	test_parameter TARGET_IMAGE_VERSION "$TARGET_IMAGE_VERSION" optional
	test_parameter BUILD_IMAGE_NAME "$BUILD_IMAGE_NAME" optional
	test_parameter BUILD_IMAGE_VERSION "$BUILD_IMAGE_VERSION" optional
	test_parameter BUILD_WITH_HOST_CONFIG_DIR "$BUILD_WITH_HOST_CONFIG_DIR" optional
	test_parameter RUN_WITH_HOST_CONFIGURATION_DIR "$RUN_WITH_HOST_CONFIGURATION_DIR" optional
	
	# The empty parameters are configured with default values
	if [ -z $HOST_NAME ]; then
		HOST_NAME="<host>.<domain>"
		echo Parameter HOST_NAME set to "$HOST_NAME"
	fi

	if [ -z $TARGET_IMAGE_NAME ]; then
		TARGET_IMAGE_NAME="janus"
		echo Parameter TARGET_IMAGE_NAME set to "$TARGET_IMAGE_NAME"
	fi

	if [ -z $TARGET_IMAGE_VERSION ]; then
		TARGET_IMAGE_VERSION="latest"
		echo Parameter TARGET_IMAGE_VERSION set to "$TARGET_IMAGE_VERSION"
	fi

	if [ -z $BUILD_IMAGE_NAME ]; then
		BUILD_IMAGE_NAME="janus_build"
		echo Parameter BUILD_IMAGE_NAME set to "$BUILD_IMAGE_NAME"
	fi

	if [ -z $BUILD_IMAGE_VERSION ]; then
		BUILD_IMAGE_VERSION="latest"
		echo Parameter BUILD_IMAGE_VERSION set to "$BUILD_IMAGE_VERSION"
	fi

	if [ "$BUILD_WITH_HOST_CONFIG_DIR" == 'true' ]; then
		echo
		echo "Using Janus gateway configuration from host folder $JANUS_SRC_CONFIG_DIR"
		CONFIG_DIR_MOUNT="-v $JANUS_SRC_CONFIG_DIR:/image/janus_config"
	else
		echo
		echo "Using Janus gateway configuration from build image (copied during the build image creation)"
		CONFIG_DIR_MOUNT=""
	fi
	
	FULL_BUILD_IMAGE_NAME=$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION
	FULL_TARGET_IMAGE_NAME=$TARGET_IMAGE_NAME:$TARGET_IMAGE_VERSION
	
	# Create the target image
	docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock $CONFIG_DIR_MOUNT \
	-e "JANUS_REPO=$JANUS_REPO" \
	-e "JANUS_VERSION=$JANUS_VERSION" \
	-e "TARGET_IMAGE_NAME=$TARGET_IMAGE_NAME" \
	-e "TARGET_IMAGE_VERSION=$TARGET_IMAGE_VERSION" \
	$FULL_BUILD_IMAGE_NAME
	
	# If required, add an extension to the command displayed below that allows the container to mount and use a host configuration folder
	if [ "$RUN_WITH_HOST_CONFIGURATION_DIR" == "true" ]; then
		COMMAND_EXTENSION=" -v $JANUS_SRC_CONFIG_DIR:/janus/etc/janus_host -e \"RUN_WITH_HOST_CONFIGURATION_DIR=true\""
	fi
	
	echo
	echo "To execute the Janus gateway target image non-interactively issue the following command: "
	echo "docker run --rm -d -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive -v /var/janus/recordings:/janus/bin/janus-recordings $COMMAND_EXTENSION $FULL_TARGET_IMAGE_NAME "
	echo
	echo "To execute the Janus gateway target image interactively issue the following command: "
	echo "docker run --rm -it -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive -v /var/janus/recordings:/janus/bin/janus-recordings $COMMAND_EXTENSION $FULL_TARGET_IMAGE_NAME"
	echo
	echo
fi





