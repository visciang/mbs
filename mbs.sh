#!/bin/sh

set -e

LOG_LEVEL=info
LOG_COLOR=true

BASEDIR=$(dirname "$0")
ABS_BASEDIR=$(realpath $BASEDIR)

alias mbs="\
    docker run --init --rm -ti \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e MBS_ROOT=$ABS_BASEDIR \
    mbs:full"

if [ "$#" -ne 0 ]; then
    mbs $@
fi
