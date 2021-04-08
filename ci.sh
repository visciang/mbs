#!/bin/sh

set -e

docker build --rm -f dockerfiles/Dockerfile --tag=mbs .

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