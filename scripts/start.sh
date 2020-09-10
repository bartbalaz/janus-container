#! /bin/bash

# Empty the mounted http directory
rm -rf /http/*

# Copy the janus http content 
cp -R /janus/http/* /http

# Start the service 
/janus/bin/janus -F /janus/etc/janus
