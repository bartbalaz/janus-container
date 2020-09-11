#! /bin/bash

# Empty the mounted http directory
echo "Removing the content of /html directory"
rm -rf /html/*

# Copy the janus http content 
echo "Copying janus samples into /html directory"
cp -R /janus/html/* /html

# Start the service 
echo "Starting the service"
/janus/bin/janus -F /janus/etc/janus
