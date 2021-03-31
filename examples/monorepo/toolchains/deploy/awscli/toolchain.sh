#!/bin/sh

set -e

SCRIPT=$2

if [ "$SCRIPT" == "" ]; then
    echo "Missing deploy script (check your toolchain_opts)"
fi

case $1 in
    deploy)
        $SCRIPT
        ;;
    destroy)
        __DESTROY__=1 $SCRIPT
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
