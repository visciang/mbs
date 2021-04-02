#!/bin/sh

set -e

LOG_LEVEL=info
LOG_COLOR=true

BASEDIR=$(dirname "$0")
ABS_BASEDIR=$(readlink -f -- "$BASEDIR")

set MBS_CACHE_VOLUME "mbs-cache"
set MBS_RELEASE_VOLUME "mbs-releases"
set MBS_GRAPH_VOLUME "$ABS_BASEDIR/.mbs-graph"

alias mbs="\
    docker run --init --rm -ti \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $MBS_CACHE_VOLUME:/.mbs-cache \
    -v $MBS_RELEASE_VOLUME:/.mbs-releases \
    -v $MBS_GRAPH_VOLUME:/.mbs-graph \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e MBS_ROOT=$ABS_BASEDIR \
    -e LOG_LEVEL=$LOG_LEVEL \
    -e LOG_COLOR=$LOG_COLOR \
    mbs:full"

if [ "$#" -ne 0 ]; then
    mbs $@
fi
