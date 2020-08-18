#! /bin/bash

# Parameters

SCRIPT_DIR=$(pwd)
ROOT_DIR=$SCRIPT_DIR/root
STAGING_DIR=$SCRIPT_DIR/staging
JANUS_DIR=$ROOT_DIR/janus
JANUS_CONFIG_DIR=$SCRIPT_DIR/janus_config
IMAGE_NAME=janus
IMAGE_VERSION=01
FULL_IMAGE_NAME=$IMAGENAME:$IMAGE_VERSION

#copy_requirement() {
#   if [ ! -d "$(dirname $ROOT_DIR$(which $1))" ]; then
#      mkdir -p $(dirname $ROOT_DIR$(which $1))
#   fi
#   cp $(which $1) $ROOT_DIR$(which $1)
#}


create_dir() {
   if [ ! -d "$1" ]; then
      mkdir -p $1
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


	echo "Installing janus-gateway Nuance.0.0.3 version"
	echo "---------------------------------------------"

	cd $STAGING_DIR
	git clone https://github.com/bartbalaz/janus-gateway.git
	cd janus-gateway
	git checkout Nuance.0.0.3
	/bin/bash $(pwd)/autogen.sh
	/bin/bash $(pwd)/configure --prefix=$JANUS_DIR --enable-post-processing
	make
	make install
	make configs
	# Remove all the unecessary files and folders (not usefull in a container context)
	rm -rf $JANUS_DIR/include
	rm -rf $JANUS_DIR/share
	# Empty the default configuration folder
	rm $JANUS_DIR/etc/janus/*
	# Copy the container configuraiton
	cp $ROOT_DIR/../$JANUS_CONFIG_DIR/* $JANUS_DIR/etc/janus/


	echo "Creating directory for mounting the certbot certificates"
	echo "--------------------------------------------------------"

	create_dir $ROOT_DIR/etc/certs
	create_dir $ROOT_DIR/archive
}

build() {
	echo "Building docker image into local repository"
	echo "-------------------------------------------"
	
	docker rmi -f $FULL_IMAGE_NAME

	docker build -t $FULL_IMAGE_NAME .
}

clean() {
	echo "Cleaning"
	echo "--------"
	
	rm -rf $STAGING_DIR
	rm -rf $ROOT_DIR
}

launch() {
	echo "Launching in interactive mode"
	echo "-----------------------------"

	docker run -it  -p 8089:8089 -p 8088:8088 -p 7889:7889 -v /etc/letsencrypt/live/bart-janus-02.eastus.cloudapp.azure.com:/etc/certs -v /etc/letsencrypt/archive:/archive janus

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
	esac
done



