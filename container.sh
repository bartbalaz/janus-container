#!/bin/bash

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
TOP_DIR=$(pwd)

ROOT_DIR=$TOP_DIR/root
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

create() {
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
	
	#--with-sysroot=$ROOT_DIR
	 
	make
	make install
	make configs 
	
	# Remove all the unecessary files and folders (not usefull in a container context)
	echo "Removing include and share directories"
	echo "--------------------------------------------------------"
	purge_dir $JANUS_DST_INCLUDE_DIR
	purge_dir $JANUS_DST_SHARE_DIR
	
	# Remove default files from the configuration folders
	echo "Removing default configuration"
	echo "--------------------------------------------------------"
	purge_dir $JANUS_DST_CONFIG_DIR
	
	# Copy the janus custom configuraiton
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
	create_dir $ROOT_DIR/etc/certs
	create_dir $ROOT_DIR/archive
	
	echo "Copying the startup script into the root directory"
	echo "--------------------------------------------------------"
	cp $SCRIPT_DIR/start.sh $ROOT_DIR
	chmod a+x $ROOT_DIR/start.sh 
	
}

build() {
    test_parameter IMAGE_NAME $IMAGE_NAME mandatory
    test_parameter IMAGE_VERSION $IMAGE_VERSION mandatory

	cd $TOP_DIR

	echo "Building docker image into local repository"
	echo "-------------------------------------------"
	
	docker build -t $FULL_IMAGE_NAME .
}

clean() {
    cd $TOP_DIR

	echo "Cleaning"
	echo "--------"
	
	rm -rf $STAGING_DIR
	rm -rf $ROOT_DIR
}

launch() {
    test_parameter IMAGE_NAME $IMAGE_NAME mandatory
    test_parameter IMAGE_VERSION $IMAGE_VERSION mandatory
    test_parameter HOST_NAME $HOST_NAME mandatory

    cd $TOP_DIR

	echo "Launching in non-interactive mode"
	echo "---------------------------------"

	docker run -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive $FULL_IMAGE_NAME

}

launchi() {
    test_parameter IMAGE_NAME $IMAGE_NAME mandatory
    test_parameter IMAGE_VERSION $IMAGE_VERSION mandatory
    test_parameter HOST_NAME $HOST_NAME mandatory

    cd $TOP_DIR

	echo "Launching in interactive mode"
	echo "-----------------------------"

	docker run -it  -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive $FULL_IMAGE_NAME\
}

help() {
	echo "$1 [create|build|clean|launch|launchi|help]"
	echo
	echo "This script permits to create, store in local registry and launch a janus-gateway image"
	echo "The following commands are available:"
	echo
	echo "create	Creates the prerequisites for the image i.e. checks out and builds the base components, creates a staging"
	echo "directory as well as a root directory that will be added to the image"
	echo "build		Bulds the Docker image using the Dockerfile and the file tree and stores it in the local Docker repository"
	echo "clean		Removes all the created prerequisites"
	echo "launch	Launches the image"
	echo "launchi	Launches the image in interactive mode"
	echo "help		Displays this image"
	echo
	echo "Multiple commands may be specified, please note that the commands are execued in the order they are specified"
	echo 
	echo "The script requires the following environment variables:"
	echo
	echo "JANUS_REPO - Repository to fetch Janus gatweay sources from (e.g. https://github.com/bartbalaz/janus-gateway.git)"
	echo "JANUS_VERSION - Version of the Janus gateway sources to checkout (e.g. v0.10.0)"
	echo "IMAGE_NAME - Target image name (e.g. janus)"
	echo "IMAGE_VERSION - Target image version (e.g. 01)"
	echo "HOST_NAME - Name of the host including the fqdn (e.g. <host>.<domain>)" 
}

# Main script
for arg in "$@" 
do
	case $arg in 
		create) 
			create
			;;
		build)
			build
			;;
		clean)
			clean
			;;
		launch)
			launch
			;;
		launchi)
			launchi
			;;
		help)
			help $0
			;;
	esac
done



