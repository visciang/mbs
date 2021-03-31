#!/bin/sh

set -e

COMMAND=$2

case $1 in
    run)
        echo "Running sh command: $COMMAND"
        eval "$COMMAND"
        ;;
    destroy)
        echo "Running sh DESTROY command: $COMMAND"
        __DESTORY__=1 eval "$COMMAND"
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
