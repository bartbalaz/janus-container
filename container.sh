#! /bin/bash

# Configuration - Set these variables to the appropriate values

# Repository to fetch Janus sources from
JANUS_REPO=

# Version of the Janus sources to checkout
JANUS_VERSION=

# Target image name
IMAGE_NAME=janus

# Target image tag
IMAGE_VERSION=01

# Name of the host including the fqdn (e.g. <host>.<domain>), please note that it may be difficult 
# to automate this parameter (e.g. by using 'hostname' command) because of the variety of
# environments where the returned values may not be appropriate
HOST_NAME=

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

create_dir() {
   if [ ! -d "$1" ]; then
      mkdir -p $1
   fi
}

purge_dir() {
   if [ -d "$1" ]; then
      rm -rf $1
   fi
}

create() {

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
	if [ -z "$JANUS_REPO"]
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
	/bin/bash $(pwd)/configure --with-sysroot=$ROOT_DIR --prefix=$JANUS_DST_DIR --enable-post-processing CFLAGS=-I$ROOT_DIR/usr/include 
	#PKG_CONFIG_PATH=$ROOT_DIR/usr/lib/pkgconfig:$ROOT_DIR/usr/lib/x86_64-linux-gnu/pkgconfig
	 
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
	cp $JANUS_SRC_CONFIG_DIR/* $JANUS_DST_CONFIG_DIR
	
	# Copy html examples
	echo "Copying the HTML examples"
	echo "--------------------------------------------------------"
	create_dir $JANUS_DST_HTML_DIR
	cp -R $JANUS_SRC_HTML_DIR/* $JANUS_DST_HTML_DIR

	echo "Creating directory for mounting the certbot certificates"
	echo "--------------------------------------------------------"

	create_dir $ROOT_DIR/etc/certs
	create_dir $ROOT_DIR/archive
	
	#Copy the startup script
	echo "Copying the startup script into the root directory"
	echo "--------------------------------------------------------"
	
	cp $SCRIPT_DIR/start.sh $ROOT_DIR
	
}

build() {
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
    cd $TOP_DIR

	echo "Launching in non-interactive mode"
	echo "---------------------------------"

	docker run -p 8089:8089 -p 7889:7889 -v /var/www/html/container:/html -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive $FULL_IMAGE_NAME

}

launchi() {
    cd $TOP_DIR

	echo "Launching in interactive mode"
	echo "-----------------------------"

	docker run -it  -p 8089:8089 -p 7889:7889 -v /etc/letsencrypt/live/$HOST_NAME:/etc/certs -v /etc/letsencrypt/archive:/archive $FULL_IMAGE_NAME

}

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

	esac
done



