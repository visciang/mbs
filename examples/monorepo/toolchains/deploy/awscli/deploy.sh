#!/bin/sh

set -e

SCRIPT=$2

case $1 in
    deploy)
        $SCRIPT
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
