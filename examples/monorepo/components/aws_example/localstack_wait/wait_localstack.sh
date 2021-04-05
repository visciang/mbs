#!/bin/sh

set -e

if [ "$__DESTROY__" == "1" ]; then
    echo "No need to wait localstack on destroy"
else
    MAX_RETRY=10
    RETRY_PERIOD=4

    for RETRY in $(seq 1 $MAX_RETRY); do
        test "$(curl -s http://localhost:4566/health | jq '[(.services[])? == "running"] | all')" == "true" && break || \

        echo "Waiting localstack (attempt $RETRY / $MAX_RETRY), retrying in $RETRY_PERIOD seconds"
        sleep $RETRY_PERIOD
    done
fi
