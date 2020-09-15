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
./janus -F /janus/etc/janus
