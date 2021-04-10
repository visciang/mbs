#!/bin/sh

set -ex

MBS_VERSION=${MBS_VERSION:-latest}

docker build --rm -f dockerfiles/Dockerfile \
    --build-arg="MBS_VERSION=$MBS_VERSION" \
    --tag=visciang/mbs:$MBS_VERSION .

if [ ! -z "$RUN_IT" ]; then
    ./mbs.sh version
    ./mbs.sh --help
    ./mbs.sh build ls
    ./mbs.sh build ls --verbose
    ./mbs.sh deploy ls
    ./mbs.sh deploy ls --verbose
    ./mbs.sh deploy tree
    ./mbs.sh build outdated
    ./mbs.sh build tree
    ./mbs.sh build run --logs
    ./mbs.sh build graph
fi