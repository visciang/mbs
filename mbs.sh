#!/bin/sh

set -e

BASEDIR=$(dirname "$0")
ABS_BASEDIR=$(readlink -f -- "$BASEDIR")

MBS_VERSION=${MBS_VERSION:-latest}

LOG_LEVEL="info"
LOG_COLOR="true"

MBS_PROJECT_ID="mbs"
MBS_LOCAL_CACHE_VOLUME="mbs-$MBS_PROJECT_ID-local-cache"
MBS_RELEASES_VOLUME="mbs-$MBS_PROJECT_ID-releases"
MBS_GRAPH_VOLUME="$ABS_BASEDIR/.mbs-graph"

# [OPTIONAL] external cache for artifacts files and docker images
MBS_PUSH=${MBS_PUSH:-"false"}
V_MBS_CACHE_VOLUME=""
MBS_DOCKER_REGISTRY=""

if [ "$MBS_PUSH" = "true" ]; then
    # Set with your endpoints
    MBS_CACHE_VOLUME="/nfs_share/mbs-$MBS_PROJECT_ID-cache"
    V_MBS_CACHE_VOLUME="-v $MBS_CACHE_VOLUME:/mbs-cache"
    MBS_DOCKER_REGISTRY="http://localhost:5000"
fi

TTY="-ti"
if [ ! -t 1 ]; then
    TTY="";
fi

alias mbs="\
    docker run --init --rm $TTY \
    --net host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $V_MBS_CACHE_VOLUME \
    -v $MBS_LOCAL_CACHE_VOLUME:/.mbs-local-cache \
    -v $MBS_RELEASES_VOLUME:/.mbs-releases \
    -v $MBS_GRAPH_VOLUME:/.mbs-graph \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e LOG_LEVEL=$LOG_LEVEL \
    -e LOG_COLOR=$LOG_COLOR \
    -e MBS_PROJECT_ID=$MBS_PROJECT_ID \
    -e MBS_PUSH=$MBS_PUSH \
    -e MBS_DOCKER_REGISTRY=$MBS_DOCKER_REGISTRY \
    -e MBS_LOCAL_CACHE_VOLUME=$MBS_LOCAL_CACHE_VOLUME \
    -e MBS_RELEASES_VOLUME=$MBS_RELEASES_VOLUME \
    visciang/mbs:$MBS_VERSION"

if [ "$#" -ne 0 ]; then
    mbs $@
fi
