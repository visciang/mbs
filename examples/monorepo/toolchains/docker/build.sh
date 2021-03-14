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
        mkdir .cache/

        MBS_DEPS_VARS=$(env | grep -o -E "MBS_DEPS_[^=]+" || echo "")
        for MBS_DEPS_VAR in $MBS_DEPS_VARS; do
            echo "Copy $MBS_DEPS_VAR in build context"
            cp $(printenv $MBS_DEPS_VAR)/* .cache/
        done

        eval docker image build ${EXTRA_ARGS} --rm --file ${FILE} --tag ${MBS_ID}:${MBS_CHECKSUM} .
        
        rm -rf .cache/
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
