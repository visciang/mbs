#!/bin/sh

set -e

MBS_VERSION=${MBS_VERSION:-latest}

docker buildx build --rm \
    --file dockerfiles/Dockerfile \
    --build-arg="MBS_VERSION=$MBS_VERSION" \
    --tag=visciang/mbs:$MBS_VERSION .
