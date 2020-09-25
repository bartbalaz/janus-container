#! /bin/bash

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

# Empty the mounted http directory
echo
echo " Removing the content of /html directory "
echo "-----------------------------------------"
rm -rf /html/*

# Copy the janus http content 
echo
echo " Copying janus samples into /html directory "
echo "--------------------------------------------"
cp -R /janus/html/* /html

# Start the service 
echo " Starting the service "
echo "----------------------"
cd /janus/bin

$CONFIG_DIR="/janus/etc/janus"
if [ "$RUN_WITH_HOST_CONFIGURATION_DIR" == "true"]; then
	$CONFIG_DIR="/janus/etc/janus_host"
fi
echo Running janus with configuration directory: "$CONFIG_DIR"
./janus -F $CONFIG_DIR
