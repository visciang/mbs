#!/bin/sh

set -e

docker build --rm --target slim --tag mbs:slim .
docker build --rm --target full --tag mbs:full .

alias mbs="docker run --init --rm -ti -v $PWD:$PWD -v /var/run/docker.sock:/var/run/docker.sock -w $PWD mbs:slim"

mbs version
mbs ls --verbose
mbs run
