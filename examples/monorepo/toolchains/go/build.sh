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

export GOPATH=/tmp/gopath
mkdir -p $GOPATH/bin
mkdir -p $GOPATH/pkg
mkdir -p $GOPATH/src

export MONOREPO=$GOPATH/src/monorepo.com
mkdir -p $MONOREPO

MBS_DEPS_VARS=$(env | grep -o -E "MBS_DEPS_[^=]+" || echo "")
for MBS_DEPS_VAR in $MBS_DEPS_VARS; do
    echo "Copy $MBS_DEPS_VAR in build context"
    tar xzf $(printenv $MBS_DEPS_VAR)/*.tgz -C $MONOREPO/
done

ln -s $MBS_CWD $MONOREPO/

case $1 in
    build)
        go build

        case $TYPE in
            lib)
                rm -f $MBS_ID.tgz
                cd ..
                tar czf /tmp/$MBS_ID.tgz $MBS_ID
                cd -
                mv /tmp/$MBS_ID.tgz .
                ;;
            app)
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
