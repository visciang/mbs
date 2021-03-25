#!/bin/sh

set -e

case $1 in
    build)
        rm -rf .build
        mkdir .build
        docker-compose config > .build/docker-compose.yml
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
