#!/bin/bash

echo
echo "************"
echo " Running $0 "
echo "************" 
echo

# Configuration - Set these parameters to the appropriate values, we suggest to create a configuration file with 
# a set of export statements that is "source'd" before the execution of this script

# JANUS_REPO - Repository to fetch Janus gatweay sources from (e.g. https://github.com/bartbalaz/janus-gateway.git)
# JANUS_VERSION - Version of the Janus gateway sources to checkout (e.g. v0.10.0)
# IMAGE_NAME - Target image name (e.g. janus)
# IMAGE_VERSION - Target image version (e.g. 01) 
# HOST_NAME - Name of the host including the fqdn (e.g. <host>.<domain>), please note that it may be difficult 
# to universally automate this parameter (e.g. by using 'hostname' command) because of the variety of
# environments where the returned values may not be appropriate 

# Global variables - Should not need to be modified
TOP_DIR=/

ROOT_DIR=$TOP_DIR/image_root
STAGING_DIR=$TOP_DIR/staging
SCRIPT_DIR=$TOP_DIR/scripts

JANUS_SRC_CONFIG_DIR=$TOP_DIR/janus_config
JANUS_SRC_HTML_DIR=$STAGING_DIR/janus/html

JANUS_DST_DIR=$ROOT_DIR/janus
JANUS_DST_HTML_DIR=$JANUS_DST_DIR/html
JANUS_DST_HTML_MOUNT_DIR=$ROOT_DIR/html
JANUS_DST_INCLUDE_DIR=$JANUS_DST_DIR/include
JANUS_DST_SHARE_DIR=$JANUS_DST_DIR/share
JANUS_DST_CONFIG_DIR=$JANUS_DST_DIR/etc/janus
JANUS_DST_RECORDING_DIR=$JANUS_DST_DIR/bin/janus/janus-recordings

CERTIFICATE_LINKS_DIR=$ROOT_DIR/etc/certs
CERTIFICATE_ARCHIVE_DIR=$ROOT_DIR/archive

START_SCRIPT_SRC=$SCRIPT_DIR/start.sh
START_SCRIPT_DST=$ROOT_DIR/start.sh 

JANUS_CLONE_DIR=$STAGING_DIR/janus
FULL_IMAGE_NAME=$IMAGE_NAME:$IMAGE_VERSION

# create_dir PATH
create_dir() {
	if [ ! -d "$1" ]; then
		mkdir -p $1
	fi
}

# purge_dir PATH
purge_dir() {
	if [ -d "$1" ]; then
		rm -rf $1
	fi
}

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

test_parameter JANUS_REPO $JANUS_REPO optional
test_parameter JANUS_REPO $JANUS_VERSION optional

echo "Creating root and staging directories"
echo "-------------------------------------"

create_dir $ROOT_DIR
create_dir $STAGING_DIR

echo "Installing libnice (latest avaialble version)"
echo "---------------------------------------------"

cd $STAGING_DIR
git clone https://gitlab.freedesktop.org/libnice/libnice
cd libnice
meson --prefix=$ROOT_DIR/usr build && ninja -C build &&  ninja -C build install 

echo "Installing libsrtp-2.2.0"
echo "------------------------"

cd $STAGING_DIR
wget https://github.com/cisco/libsrtp/archive/v2.2.0.tar.gz
tar xfv v2.2.0.tar.gz
cd libsrtp-2.2.0
./configure --prefix=$ROOT_DIR/usr --enable-openssl
make shared_library && make install

echo "Installing janus-gateway"
echo "---------------------------------------------"
cd $STAGING_DIR
if [ -z "$JANUS_REPO" ]
then 
	echo "Cloning from default repo to $JANUS_CLONE_DIR"
	git clone https://github.com/meetecho/janus-gateway.git $JANUS_CLONE_DIR
else
	echo "Cloning from $JANUS_REPO to $JANUS_CLONE_DIR"
	git clone $JANUS_REPO $JANUS_CLONE_DIR
fi
cd $JANUS_CLONE_DIR
[ ! -z "$JANUS_VERSION" ] && git checkout $JANUS_VERSION
/bin/bash $(pwd)/autogen.sh

export PKG_CONFIG_PATH=$ROOT_DIR/usr/lib/pkgconfig:$ROOT_DIR/usr/lib/x86_64-linux-gnu/pkgconfig 
/bin/bash $(pwd)/configure --prefix=$JANUS_DST_DIR CFLAGS=-I$ROOT_DIR/usr/include 
 
make
make install
make configs 

echo "Removing include and share directories"
echo "--------------------------------------------------------"
purge_dir $JANUS_DST_INCLUDE_DIR
purge_dir $JANUS_DST_SHARE_DIR

echo "Removing default configuration"
echo "--------------------------------------------------------"
purge_dir $JANUS_DST_CONFIG_DIR

echo "Copying custop configuration"
echo "--------------------------------------------------------"
mkdir $JANUS_DST_CONFIG_DIR
cp $JANUS_SRC_CONFIG_DIR/* $JANUS_DST_CONFIG_DIR

echo "Copying the Janus HTML examples"
echo "--------------------------------------------------------"
create_dir $JANUS_DST_HTML_DIR
create_dir $JANUS_DST_HTML_MOUNT_DIR
cp -R $JANUS_SRC_HTML_DIR/* $JANUS_DST_HTML_DIR

echo "Creating directory for mounting the certbot certificates"
echo "--------------------------------------------------------"
create_dir $CERTIFICATE_LINKS_DIR
create_dir $CERTIFICATE_ARCHIVE_DIR

echo "Creating directory for saving the recordings"
echo "--------------------------------------------------------"
createdir $JANUS_DST_RECORDING_DIR

echo "Copying the startup script into the root directory"
echo "--------------------------------------------------------"
cp $START_SCRIPT_SRC $START_SCRIPT_DST
chmod a+x $START_SCRIPT_DST
