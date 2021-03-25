#!/bin/sh

set -e

FILE="Dockerfile"
EXTRA_ARGS=""

args()
{
    options=$(
        getopt --long file: --long extra-args: -- "$@"
    )
    if [ $? != 0 ]; then
        echo "Incorrect option provided"
        exit 1
    fi

    eval set -- "$options"

    while true; do
        case "$1" in
        --file)
            shift;
            FILE=$1
            ;;
        --extra-args)
            shift;
            EXTRA_ARGS=$1
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
    build)
        rm -rf .cache/

        MBS_DIR_VARS=$(env | grep -o -E "MBS_DIR_[^=]+" || echo "")
        for MBS_DIR_VAR in $MBS_DIR_VARS; do
            DIR=.cache/$MBS_DIR_VAR
            mkdir -p $DIR
            echo "Copy $MBS_DIR_VAR in build context -> $DIR"
            cp $(printenv $MBS_DIR_VAR)/* $DIR/
        done

        eval docker image build ${EXTRA_ARGS} --rm --file ${FILE} --tag ${MBS_ID}:${MBS_CHECKSUM} .
        
        rm -rf .cache/
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
