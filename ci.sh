#!/bin/sh

set -e

docker build --rm -f dockerfiles/Dockerfile --target slim --tag mbs:slim .
docker build --rm -f dockerfiles/Dockerfile --target full --tag mbs:full .

alias mbs="\
    docker run --init --rm -ti \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $PWD:$PWD \
    -w $PWD \
    -e MBS_ROOT=$PWD \
    mbs:slim"

mbs version
mbs ls --verbose
mbs run
