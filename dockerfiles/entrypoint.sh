#!/bin/sh

set -e

MBS=/usr/local/bin/mbs
CMD=$1

if [ $CMD == "shell" ]; then
    $MBS $@

    SHELL_TARGET=$2
    DOCKER_CMD=$($MBS shell $SHELL_TARGET --docker-cmd)

    echo -e "\nStarting interactive toolchain shell ...\n"
    $DOCKER_CMD
else
    $MBS $@
fi
