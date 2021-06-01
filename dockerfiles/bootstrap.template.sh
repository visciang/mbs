DOCKER_DIND_NAME="mbs-$MBS_PROJECT_ID-dind"
DOCKER_DIND_ID="$(docker ps --filter name="^/$DOCKER_DIND_NAME\$" --format "{{ .ID }}")"

if [ -z "$DOCKER_DIND_ID" ]; then
    docker run --detach --privileged --rm \
        --name="$DOCKER_DIND_NAME" --hostname="$DOCKER_DIND_NAME" \
        --env DOCKER_TLS_CERTDIR="" \
        --env DOCKER_TLS_VERIFY="" \
        --volume="$DOCKER_DIND_NAME-artifacts":/mbs \
        --volume="$DOCKER_DIND_NAME-docker":/var/lib/docker \
        --volume="$BASEDIR":"$BASEDIR" \
        docker:20.10.6-dind

    echo "Starting Docker DIND daemon ($DOCKER_DIND_NAME), please wait few seconds ..."
    
    docker exec $DOCKER_DIND_NAME docker version

    echo "\nDocker DIND UP."
fi

if [ "$MBS_PUSH" = "true" ]; then
    V_MBS_REMOTE_CACHE_VOLUME="--volume \"$MBS_REMOTE_CACHE_VOLUME\":/mbs-cache"
else
    V_MBS_REMOTE_CACHE_VOLUME=""
fi

TTY="-ti"
if [ ! -t 1 ]; then
    TTY="";
fi

docker run --init --rm $TTY \
    --link="$DOCKER_DIND_NAME" \
    --env DOCKER_HOST="tcp://$DOCKER_DIND_NAME:2375" \
    --env DOCKER_TLS_CERTDIR="" \
    --env DOCKER_TLS_VERIFY="" \
    --volume="$DOCKER_DIND_NAME-artifacts":/mbs \
    --volume="$BASEDIR":"$BASEDIR" \
    $V_MBS_REMOTE_CACHE_VOLUME \
    --workdir="$BASEDIR" \
    visciang/mbs:$MBS_VERSION $@
