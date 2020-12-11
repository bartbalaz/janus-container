#! /bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

# Empty the mounted http directory
if [ "$COPY_JANUS_SAMPLES" == "true" ]; then
	echo
	echo " Removing the content of /html directory "
	echo "-----------------------------------------"
	rm -rf /html/*

	# Copy the janus http content 
	echo
	echo " Copying janus samples into /html directory "
	echo "--------------------------------------------"
	cp -R /janus/html/* /html
else
	echo
	echo " Janus samples are disabled "
	echo "----------------------------"
fi

# Start the service 
echo " Starting the service "
echo "----------------------"
# Image information printout
cat /build.info

cd /janus/bin

CONFIG_DIR="/janus/etc/janus"
if [ "$RUN_WITH_HOST_CONFIGURATION_DIR" == "true" ]; then
	CONFIG_DIR="/janus/etc/janus_host"
fi
echo Running janus with configuration directory: "$CONFIG_DIR"
./janus -F "$CONFIG_DIR"
