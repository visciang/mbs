#!/bin/sh

set -e


case $1 in
    build)
        BUILD_DIR=.build
        rm -rf $BUILD_DIR
        mkdir $BUILD_DIR
        cd $BUILD_DIR
        cmake ../
        make
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac