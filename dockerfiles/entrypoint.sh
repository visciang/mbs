#!/bin/sh

set -e

MBS=/usr/local/bin/mbs
CMD=$1
SUBCMD=$2

if [ "$CMD" == "bootstrap" ]; then
    LOG_LEVEL=$(jq -r '.log.level' .mbs-config.json) \
    LOG_COLOR=$(jq -r '.log.color' .mbs-config.json) \
    MBS_PROJECT_ID=$(jq -r '.project' .mbs-config.json) \
    MBS_RELEASES_VOLUME=$(jq -r '.volume.releases' .mbs-config.json) \
    MBS_GRAPH_VOLUME=$(jq -r '.volume.graph' .mbs-config.json) \
    MBS_PUSH=$(jq -r '.cache.remote.push' .mbs-config.json) \
    MBS_REMOTE_CACHE_VOLUME=$(jq -r '.cache.remote.volume' .mbs-config.json) \
    MBS_DOCKER_REGISTRY=$(jq -r '.cache.remote.docker_registry' .mbs-config.json) \
    MBS_LOCAL_CACHE_VOLUME=$(jq -r '.cache.local.volume' .mbs-config.json) \
    envsubst '
        ${LOG_LEVEL}
        ${LOG_COLOR}
        ${MBS_PROJECT_ID}
        ${MBS_RELEASES_VOLUME}
        ${MBS_GRAPH_VOLUME}
        ${MBS_PUSH}
        ${MBS_REMOTE_CACHE_VOLUME}
        ${MBS_DOCKER_REGISTRY}
        ${MBS_LOCAL_CACHE_VOLUME}' \
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
