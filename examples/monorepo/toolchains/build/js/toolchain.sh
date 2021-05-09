#!/bin/sh

set -e

mkdir -p .build

case $1 in
    build)
        npm ci
        npm pack

        mv $MBS_ID-*.tgz .build/
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
