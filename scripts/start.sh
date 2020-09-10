#! /bin/bash

# Empty the mounted http directory
rm -rf /html/*

# Copy the janus http content 
cp -R /janus/html/* /html

# Start the service 
/janus/bin/janus -F /janus/etc/janus
