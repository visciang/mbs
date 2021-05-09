#!/bin/sh

set -e

TYPE="app"

args()
{
    options=$(
        getopt --long type: -- "$@"
    )
    if [ $? != 0 ]; then
        echo "Incorrect option provided"
        exit 1
    fi

    eval set -- "$options"

    while true; do
        case "$1" in
        --type)
            shift;
            TYPE=$1

            case $TYPE in
                lib|app)
                    ;;
                *)
                    echo "Unknown build type: $TYPE"
                    exit 1
            esac
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

export GOPATH=$(readlink -f -- ../)
mkdir -p $GOPATH/bin
mkdir -p $GOPATH/pkg
mkdir -p $GOPATH/src

case $1 in
    build)
        rm -rf .build/ && mkdir .build/

        case $TYPE in
            lib)
                go build -o .build/$MBS_ID.ar
                ;;
            app)
                go build -o .build/$MBS_ID
                ;;
        esac
        ;;
    lint)
        RES=$(gofmt -l .)

        if [ "$RES" != "" ]; then
            echo "FILES NOT FORMATTED (goftm):"
            echo $RES
            exit 1
        fi
        ;;
    test)
        go test
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
