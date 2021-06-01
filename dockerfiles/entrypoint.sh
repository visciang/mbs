#!/bin/sh

set -e

MBS=/usr/local/bin/mbs
CMD=$1
SUBCMD=$2

if [ "$CMD" == "bootstrap" ]; then
    MBS_PROJECT_ID=$(jq -r '.project' .mbs-config.json) \
    MBS_PUSH=$(jq -r '.cache.push' .mbs-config.json) \
    MBS_REMOTE_CACHE_VOLUME=$(jq -r '.cache.volume' .mbs-config.json) \
    envsubst '
        ${MBS_PROJECT_ID}
        ${MBS_PUSH}
        ${MBS_REMOTE_CACHE_VOLUME}' \
        < /bootstrap.template.sh
elif [ "$CMD" == "build" ] && [ "$SUBCMD" == "shell" ]; then
    $MBS $@

    SHELL_TARGET=$3
    DOCKER_CMD=$($MBS build shell $SHELL_TARGET --docker-cmd)

    echo -e "\nStarting interactive toolchain shell ...\n"
    eval $DOCKER_CMD
elif [ "$CMD" == "init" ]; then
    if [ -z "$SUBCMD" ]; then
        echo "Missing project name:"
        echo "Help: init <YOUR_PROJECT_NAME>"
        exit 1
    fi

    echo "Initializing MBS repository $SUBCMD"

    cp -r -i /repo_init/. .

    sed -i "s/MBS_PROJECT_ID/$SUBCMD/g" ./.mbs-config.json

    echo "DONE"
    echo ""
    echo "You can now run mbs in the current repo (./mbs.sh --help)"
else
    $MBS $@
fi
