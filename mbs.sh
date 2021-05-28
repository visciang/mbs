#!/bin/sh

set -e

MBS_VERSION=${MBS_VERSION:-latest}
BASEDIR=$(dirname "$0")
BASEDIR=$(readlink -f -- "$BASEDIR")

eval "$(docker run --init --rm --net host -v $BASEDIR:$BASEDIR -w $BASEDIR visciang/mbs:$MBS_VERSION bootstrap)"
