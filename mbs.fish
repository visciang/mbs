#!/bin/fish

set BASEDIR (dirname "$0")
set ABS_BASEDIR (readlink -f -- $BASEDIR)

set -q MBS_VERSION || set MBS_VERSION "latest"

set LOG_LEVEL "info"
set LOG_COLOR "true"

set MBS_PROJECT_ID "mbs"
set MBS_SANDBOX_VOLUME "mbs-$MBS_PROJECT_ID-sandbox"
set MBS_LOCAL_CACHE_VOLUME "mbs-$MBS_PROJECT_ID-local-cache"
set MBS_RELEASES_VOLUME "mbs-$MBS_PROJECT_ID-releases"
set MBS_GRAPH_VOLUME "$ABS_BASEDIR/.mbs-graph"

# [OPTIONAL] external cache for artifacts files and docker images
set -q MBS_PUSH || set MBS_PUSH "false"
set MBS_CACHE_VOLUME ""
set MBS_DOCKER_REGISTRY ""

if test "$MBS_PUSH" = "true"
    # Set with your endpoints
    set MBS_CACHE_VOLUME "/nfs_share/mbs-$MBS_PROJECT_ID-cache"
    set MBS_DOCKER_REGISTRY "http://localhost:5000"
end

set TTY "-ti"
if not isatty
    set TTY ""
end

alias mbs="\
    docker run --init --rm $TTY \
    --net host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $MBS_CACHE_VOLUME:/mbs-cache \
    -v $MBS_SANDBOX_VOLUME:/mbs-sandbox \
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
    -e MBS_SANDBOX_VOLUME=$MBS_SANDBOX_VOLUME \
    -e MBS_LOCAL_CACHE_VOLUME=$MBS_LOCAL_CACHE_VOLUME \
    -e MBS_RELEASES_VOLUME=$MBS_RELEASES_VOLUME \
    visciang/mbs:$MBS_VERSION"

if [ (count $argv) != 0 ]
    mbs $argv
end
