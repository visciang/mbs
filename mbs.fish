#!/bin/fish

set -q MBS_VERSION || set MBS_VERSION latest

set LOG_LEVEL info
set LOG_COLOR true

set BASEDIR (dirname "$0")
set ABS_BASEDIR (readlink -f -- $BASEDIR)

set MBS_PROJECT_ID mbs
set MBS_CACHE_VOLUME mbs-$MBS_PROJECT_ID-cache
set MBS_RELEASES_VOLUME mbs-$MBS_PROJECT_ID-releases
set MBS_GRAPH_VOLUME $ABS_BASEDIR/.mbs-graph

set TTY "-ti"
if not isatty
    set TTY ""
end

alias mbs="\
    docker run --init --rm $TTY \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $MBS_CACHE_VOLUME:/.mbs-cache \
    -v $MBS_RELEASES_VOLUME:/.mbs-releases \
    -v $MBS_GRAPH_VOLUME:/.mbs-graph \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e MBS_CACHE_VOLUME=$MBS_CACHE_VOLUME \
    -e MBS_RELEASES_VOLUME=$MBS_RELEASES_VOLUME \
    -e MBS_GRAPH_VOLUME=$MBS_GRAPH_VOLUME \
    -e LOG_LEVEL=$LOG_LEVEL \
    -e LOG_COLOR=$LOG_COLOR \
    visciang/mbs:$MBS_VERSION"

if [ (count $argv) != 0 ]
    mbs $argv
end
