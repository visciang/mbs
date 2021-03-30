#!/bin/sh

set -e

apk add --quiet --no-cache curl jq

MAX_RETRY=10
RETRY_PERIOD=4

for RETRY in $(seq 1 $MAX_RETRY); do
    test "$(curl -s http://localhost:4566/health | jq '[.services[] == "running"] | all')" == "true" && break || \
    sleep $RETRY_PERIOD
    echo "Waiting localstack (attempt $RETRY / $MAX_RETRY), retrying in $RETRY_PERIOD seconds"
done