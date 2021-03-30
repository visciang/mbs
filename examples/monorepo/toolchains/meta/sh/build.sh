#!/bin/sh

set -e

COMMAND=$2

case $1 in
    build)
        echo "Running sh command: $COMMAND"
        eval "$COMMAND"
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
