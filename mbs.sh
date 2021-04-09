#!/bin/sh

set -e

LOG_LEVEL=info
LOG_COLOR=true

BASEDIR=$(dirname "$0")
ABS_BASEDIR=$(readlink -f -- "$BASEDIR")

MBS_CACHE_VOLUME="mbs-cache"
MBS_RELEASE_VOLUME="mbs-releases"
MBS_GRAPH_VOLUME="$ABS_BASEDIR/.mbs-graph"

TTY="-ti"
if [ ! -t 1 ]; then TTY=""; fi

alias mbs="\
    docker run --init --rm $TTY \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $MBS_CACHE_VOLUME:/.mbs-cache \
    -v $MBS_RELEASE_VOLUME:/.mbs-releases \
    -v $MBS_GRAPH_VOLUME:/.mbs-graph \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e MBS_CACHE_VOLUME=$MBS_CACHE_VOLUME \
    -e MBS_RELEASE_VOLUME=$MBS_RELEASE_VOLUME \
    -e MBS_GRAPH_VOLUME=$MBS_GRAPH_VOLUME \
    -e LOG_LEVEL=$LOG_LEVEL \
    -e LOG_COLOR=$LOG_COLOR \
    mbs"

if [ "$#" -ne 0 ]; then
    mbs $@
fi
