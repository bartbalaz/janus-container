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
# HOST_NAME - Name of the host including the fqdn (e.g. <host>.<domain>), please note that it may be difficult 
# to universally automate this parameter (e.g. by using 'hostname' command) because of the variety of
# environments where the returned values may not be appropriate 

# Global variables - Should not need to be modified

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

echo
echo " Testing parameters "
echo "--------------------"

test_parameter JANUS_REPO $JANUS_REPO optional
test_parameter JANUS_REPO $JANUS_VERSION optional
test_parameter TARGET_IMAGE_NAME $TARGET_IMAGE_NAME mandatory
test_parameter TARGET_IMAGE_VERSION $TARGET_IMAGE_VERSION mandatory
test_parameter BUILD_IMAGE_NAME $BUILD_IMAGE_NAME mandatory
test_parameter BUILD_IMAGE_VERSION $BUILD_IMAGE_VERSION mandatory

echo
echo " Bulding build image "
echo "---------------------"
docker build -t $FULL_BUILD_IMAGE_NAME -f Dockerfile.build . 

echo
echo " Executing the buld image "
echo "--------------------------"
docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock \
-e "JANUS_REPO=$JANUS_REPO" \
-e "JANUS_VERSION=$JANUS_VERSION" \
-e "TARGET_IMAGE_NAME=$TARGET_IMAGE_NAME" \
-e "TARGET_IMAGE_VERSION=$TARGET_IMAGE_VERSION" \
-e "HOST_NAME=$HOST_NAME" \
$FULL_BUILD_IMAGE_NAME

echo
echo "To execute the Janus target image non-interactively issue the following command: "
echo "docker run --rm -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive/$HOST_NAME:/archive -v /var/janus/recordings:/janus/bin/janus-recordings $FULL_TARGET_IMAGE_NAME"
echo
echo "To execute the Janus target image interactively issue the following command: "
echo "docker run --rm -it -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive/$HOST_NAME:/archive -v /var/janus/recordings:/janus/bin/janus-recordings $FULL_TARGET_IMAGE_NAME"





