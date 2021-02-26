#!/bin/sh

set -e

docker build --target slim --tag mbs:slim .
docker build --target full --tag mbs:full .

alias mbs="docker run --rm --volume $PWD:/code -w /code mbs:slim"

mbs version
mbs ls --verbose
mbs run
