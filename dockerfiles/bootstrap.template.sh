DOCKER_DIND_NAME="mbs-$MBS_PROJECT_ID-dind"
DOCKER_DIND_ID="$(docker ps --filter name="^/$DOCKER_DIND_NAME\$" --format "{{ .ID }}")"

if [ -z "$DOCKER_DIND_ID" ]; then
    echo "Starting Docker DIND daemon ($DOCKER_DIND_NAME)"

    docker network create "$DOCKER_DIND_NAME"

    docker run --detach --privileged --rm \
        --name="$DOCKER_DIND_NAME" --hostname="$DOCKER_DIND_NAME" \
        --network="$DOCKER_DIND_NAME" \
        --env DOCKER_TLS_CERTDIR="" \
        --env DOCKER_TLS_VERIFY="" \
        --volume="$DOCKER_DIND_NAME-artifacts":/mbs \
        --volume="$DOCKER_DIND_NAME-docker":/var/lib/docker \
        --volume="$BASEDIR":"$BASEDIR" \
        docker:20.10.7-dind

    attempts=30

    echo "Waiting for Docker DIND to come up"

    while ! docker exec $DOCKER_DIND_NAME docker info >/dev/null 2>&1; do
        echo "Connection attempts left: $attempts"

        if [ $attempts -eq 0 ]; then
            echo "Couldn't connect to docker, no attempts left"
            exit 1
        fi;

        attempts=$(($attempts-1))
        echo "Connection to docker failed"
        sleep 2
    done

    echo "Docker DIND UP"
fi

if [ "$MBS_PUSH" = "true" ]; then
    V_MBS_REMOTE_CACHE_VOLUME="--volume \"$MBS_REMOTE_CACHE_VOLUME\":/mbs-remote_cache"
else
    V_MBS_REMOTE_CACHE_VOLUME=""
fi

TTY="-ti"
if [ ! -t 1 ]; then
    TTY="";
fi

docker run --init --rm $TTY \
    --name=mbs-$MBS_PROJECT_ID \
    --network="$DOCKER_DIND_NAME" \
    --env DOCKER_HOST="tcp://$DOCKER_DIND_NAME:2375" \
    --env DOCKER_TLS_CERTDIR="" \
    --env DOCKER_TLS_VERIFY="" \
    --volume="$DOCKER_DIND_NAME-artifacts":/mbs \
    --volume="$BASEDIR":"$BASEDIR" \
    $V_MBS_REMOTE_CACHE_VOLUME \
    --workdir="$BASEDIR" \
    visciang/mbs:$MBS_VERSION $@
