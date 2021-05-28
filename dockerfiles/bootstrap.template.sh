if [ "$MBS_PUSH" = "true" ]; then
    V_MBS_REMOTE_CACHE_VOLUME="-v $MBS_REMOTE_CACHE_VOLUME:/mbs-cache"
else
    V_MBS_REMOTE_CACHE_VOLUME=""
fi

TTY="-ti"
if [ ! -t 1 ]; then
    TTY="";
fi

docker run --init --rm --net host $TTY \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $V_MBS_REMOTE_CACHE_VOLUME \
    -v "$MBS_LOCAL_CACHE_VOLUME":/.mbs-local-cache \
    -v "$MBS_RELEASES_VOLUME":/.mbs-releases \
    -v "$MBS_GRAPH_VOLUME":/.mbs-graph \
    -v "$BASEDIR":"$BASEDIR" \
    -w "$BASEDIR" \
    -e LOG_LEVEL="$LOG_LEVEL" \
    -e LOG_COLOR="$LOG_COLOR" \
    -e MBS_PROJECT_ID="$MBS_PROJECT_ID" \
    -e MBS_PUSH="$MBS_PUSH" \
    -e MBS_DOCKER_REGISTRY="$MBS_DOCKER_REGISTRY" \
    -e MBS_LOCAL_CACHE_VOLUME="$MBS_LOCAL_CACHE_VOLUME" \
    -e MBS_RELEASES_VOLUME="$MBS_RELEASES_VOLUME" \
    visciang/mbs:$MBS_VERSION $@
