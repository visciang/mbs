#!/bin/fish

set LOG_LEVEL info
set LOG_COLOR true

set BASEDIR (dirname "$0")
set ABS_BASEDIR (readlink -f -- $BASEDIR)

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
    -e MBS_CACHE_VOLUME=$MBS_CACHE_VOLUME \
    -e MBS_RELEASE_VOLUME=$MBS_RELEASE_VOLUME \
    -e MBS_GRAPH_VOLUME=$MBS_GRAPH_VOLUME \
    -e LOG_LEVEL=$LOG_LEVEL \
    -e LOG_COLOR=$LOG_COLOR \
    mbs:full"

if [ (count $argv) != 0 ]
    mbs $argv
end
