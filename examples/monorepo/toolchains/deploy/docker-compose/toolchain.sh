#!/bin/sh

set -e

LOAD_ONLY=0

args()
{
    options=$(
        getopt --long load-only -- "$@"
    )
    if [ $? != 0 ]; then
        echo "Incorrect option provided"
        exit 1
    fi

    eval set -- "$options"

    while true; do
        case "$1" in
        --load-only)
            LOAD_ONLY=1
            ;;
        --)
            shift
            break
            ;;
        esac
        shift
    done
}

args $0 "$@"

case $1 in
    deploy)
        if [ $LOAD_ONLY == 0 ]; then
            docker-compose up -d
        else
            # nothing to do
            echo "PASS"
        fi
        ;;
    destroy)
        if [ $LOAD_ONLY == 0 ]; then
            docker-compose down --volumes --remove-orphans
        else
            # nothing to do
            echo "PASS"
        fi
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
