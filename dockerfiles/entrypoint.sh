#!/bin/sh

set -e

MBS=/usr/local/bin/mbs
CMD=$1
SUBCMD=$2

if [ "$CMD" == "bootstrap" ]; then
    MBS_PROJECT_ID=$(jq -r '.project' .mbs-config.json)
    MBS_PUSH=$(jq -r '.remote_cache.push' .mbs-config.json)
    MBS_REMOTE_CACHE_VOLUME=$(jq -r '.remote_cache.volume' .mbs-config.json)
    MBS_REMOTE_CACHE_DOCKER_REGISTRY=$(jq -r '.remote_cache.docker_registry' .mbs-config.json)

    if [ "$MBS_PUSH" = "true" ]; then
        if [ "$MBS_REMOTE_CACHE_VOLUME" = "null" -o "$MBS_REMOTE_CACHE_DOCKER_REGISTRY" = "null" ]; then
            >&2 echo "Bad config: .remote_cache.push='true' implies a non null .remote_cache.volume / .remote_cache.docker_registry"
            exit 1
        fi
    fi

    MBS_PROJECT_ID=$MBS_PROJECT_ID MBS_PUSH=$MBS_PUSH MBS_REMOTE_CACHE_VOLUME=$MBS_REMOTE_CACHE_VOLUME \
    envsubst '${MBS_PROJECT_ID} ${MBS_PUSH} ${MBS_REMOTE_CACHE_VOLUME}' < /bootstrap.template.sh
elif [ "$CMD" == "build" -a "$SUBCMD" == "shell" ]; then
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
