#!/bin/fish

set LOG_LEVEL info
set LOG_COLOR true

set BASEDIR (dirname "$0")
set ABS_BASEDIR (readlink -f -- $BASEDIR)

alias mbs="\
    docker run --init --rm -ti \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e MBS_ROOT=$ABS_BASEDIR \
    -e LOG_LEVEL=$LOG_LEVEL \
    -e LOG_COLOR=$LOG_COLOR \
    mbs:full"

if [ (count $argv) != 0 ]
    mbs $argv
end
