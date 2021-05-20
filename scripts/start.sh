#! /bin/bash

#
# Copyright 2020-present, Nuance, Inc. and its contributors.
# All rights reserved.
#
# This source code is licensed under the Apache Version 2.0 license found in 
# the LICENSE.md file in the root directory of this source tree.
#

set -e

echo
echo "***************************"
echo "    Running $0 "
echo "***************************" 
echo

# Image information printout
echo " Build information "
echo "-------------------"

cat /build.info

echo
echo " Parameters "
echo "------------"
echo 
echo RUN_WITH_HOST_CONFIGURATION_DIR=$RUN_WITH_HOST_CONFIGURATION_DIR
echo CONFIG_GEN_SCRIPT=$CONFIG_GEN_SCRIPT

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

# Set the configuration directory path
echo
echo " Setting the configuration directory path information "
echo "------------------------------------------------------"

CONFIG_DIR="/janus/etc/janus"
if [ "$RUN_WITH_HOST_CONFIGURATION_DIR" == "true" ]; then
  # If we are using the host configuration we have to use the "janus_host" direcotry
	CONFIG_DIR="/janus/etc/janus_host"
fi

echo
echo Running janus with configuration directory: "$CONFIG_DIR"

if [ -f $CONFIG_DIR/$CONFIG_GEN_SCRIPT ]; then 
  echo
  echo " Generating configuration files "
  echo "--------------------------------"

  # If there is a config generation script in the config directory invoke it.
  echo
  echo Content of the $CONFIG_DIR directory before generating the configuration files:
  echo $(ls $CONFIG_DIR)
  
  echo
  echo Using $CONFIG_DIR/$CONFIG_GEN_SCRIPT to generate Janus Gateway configuration

  # Go to the configuraiton directory
  cd $CONFIG_DIR
  
  # Make sure that the scritp is executable
  chmod u+x ./$CONFIG_GEN_SCRIPT
  
  # Run the script
  ./$CONFIG_GEN_SCRIPT
  
  echo
  echo Configuration files after running the $CONFIG_GEN_SCRIPT script in $CONFIG_DIR directory:
  echo
  find . -name "*.jcfg" | xargs -I{} sh -c 'ls {}; cat {}' \;
fi

# Start the service 
echo
echo " Starting the service "
echo "----------------------"

# Change to the directory containing the Janus Gatway executable
cd /janus/bin

./janus -F "$CONFIG_DIR"
