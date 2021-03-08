#!/bin/sh

set -e

docker build --rm -f dockerfiles/Dockerfile --target slim --tag mbs:slim .
docker build --rm -f dockerfiles/Dockerfile --target full --tag mbs:full .

./mbs.sh version
./mbs.sh ls --verbose
./mbs.sh run --logs
