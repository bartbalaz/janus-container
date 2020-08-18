#! /bin/bash

create_dir() {
   if [ ! -d "$1" ]; then
      mkdir -p $1
   fi
}

ROOT_DIR=$(pwd)/root
STAGING_DIR=$(pwd)/staging
JANUS_DIR=$ROOT_DIR/janus


create_dir $ROOT_DIR
create_dir $STAGING_DIR


#copy_requirement() {
#   if [ ! -d "$(dirname $ROOT_DIR$(which $1))" ]; then
#      mkdir -p $(dirname $ROOT_DIR$(which $1))
#   fi
#   cp $(which $1) $ROOT_DIR$(which $1)
#}

cd $STAGING_DIR
git clone https://gitlab.freedesktop.org/libnice/libnice
cd libnice
meson --prefix=$ROOT_DIR/usr build && ninja -C build &&  ninja -C build install 

cd $STAGING_DIR
wget https://github.com/cisco/libsrtp/archive/v2.2.0.tar.gz
tar xfv v2.2.0.tar.gz
cd libsrtp-2.2.0
./configure --prefix=$ROOT_DIR/usr --enable-openssl
make shared_library && make install

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
cp $ROOT_DIR/../janus_config/* $JANUS_DIR/etc/janus/
# Create the directory where the certificates directory will be mounted
create_dir $ROOT_DIR/etc/certs
create_dir $ROOT_DIR/archive
