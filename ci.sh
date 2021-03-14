#!/bin/sh

set -e

docker build --rm -f dockerfiles/Dockerfile --target slim --tag mbs:slim .
docker build --rm -f dockerfiles/Dockerfile --target full --tag mbs:full .

if [ ! -z "$RUN_IT" ]; then
    ./mbs.sh version
    ./mbs.sh ls
    ./mbs.sh ls --verbose
    ./mbs.sh outdated
    ./mbs.sh tree mbs
    ./mbs.sh run --logs
    ./mbs.sh graph
fi