#!/bin/sh

set -e

COMPILE_OPTS="--warnings-as-errors"
DIALYZER=0
DIALYZER_OPTS=""
CREDO=0
CREDO_OPTS="--all --strict"
COVERALLS=0
TYPE="app"

args()
{
    options=$(
        getopt --long dialyzer --long dialyzer-opts: --long credo --long credo-opts: \
        --long coveralls --long type: --long compile-opts: -- "$@"
    )
    if [ $? != 0 ]; then
        echo "Incorrect option provided"
        exit 1
    fi

    eval set -- "$options"

    while true; do
        case "$1" in
        --dialyzer)
            DIALYZER=1
            ;;
        --dialyzer-opts)
            shift;
            DIALYZER_OPTS=$1
            ;;
        --credo)
            CREDO=1
            ;;
        --credo-opts)
            shift;
            CREDO_OPTS=$1
            ;;
        --coveralls)
            COVERALLS=1
            ;;
        --type)
            shift;
            TYPE=$1
            ;;
        --compile-opts)
            shift;
            COMPILE_OPTS=$1
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
    deps)
        mix deps.get
        ;;
    compile)
        mix compile $COMPILE_OPTS
        ;;
    lint)
        mix format --check-formatted

        CYCLES=$(mix xref graph --format=cycles)

        if [ "$CYCLES" != "No cycles found" ]; then
            echo "Found module dependency cycle:"
            echo "$CYCLES"
            exit 1
        fi

        if [ $CREDO == 1 ]; then
            mix credo $CREDO_OPTS
        fi

        if [ $DIALYZER == 1 ]; then
            mix dialyzer $DIALYZER_OPTS
        fi
        ;;
    test)
        mix test
        if [ $COVERALLS == 1 ]; then
            mix coveralls
        fi
        ;;
    build)
        case $TYPE in
            app)
                MIX_ENV=prod mix release
                ;;
            escript)
                MIX_ENV=prod mix escript.build
                ;;
            *)
                echo "Unknown build type: $TYPE"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
