#!/bin/sh

set -e

MBS=/usr/local/bin/mbs
CMD=$1
SUBCMD=$2

if [ "$CMD" == "build" ] && [ "$SUBCMD" == "shell" ]; then
    $MBS $@

    SHELL_TARGET=$3
    DOCKER_CMD=$($MBS build shell $SHELL_TARGET --docker-cmd)

    echo -e "\nStarting interactive toolchain shell ...\n"
    eval $DOCKER_CMD
elif [ "$CMD" == "init" ]; then
    echo "Initializing repository ..."

    cp -r -i /repo_init/. .

    echo "DONE"
    echo ""
    echo "You can now run mbs in the current repo (./mbs.sh --help)"
else
    $MBS $@
fi
