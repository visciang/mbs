#!/bin/fish

set BASEDIR (dirname "$0")
set ABS_BASEDIR (realpath $BASEDIR)

alias mbs="\
    docker run --init --rm -ti \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $ABS_BASEDIR:$ABS_BASEDIR \
    -w $ABS_BASEDIR \
    -e MBS_ROOT=$ABS_BASEDIR \
    mbs:full"

if [ (count $argv) != 0 ]
    mbs $argv
end
