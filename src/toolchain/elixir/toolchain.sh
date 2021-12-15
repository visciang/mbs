#!/bin/sh

set -e

DIALYZER=0
DIALYZER_OPTS=""
TYPE="escript"

args()
{
    options=$(
        getopt --long dialyzer --long dialyzer-opts: --long type: -- "$@"
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
                ;;
            --dialyzer)
                DIALYZER=1
                ;;
            --dialyzer-opts)
                shift;
                DIALYZER_OPTS=$1
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
    cache)
        rm -rf _build && mkdir -p _build

        mix deps.get
        MIX_ENV=dev mix deps.compile
        MIX_ENV=prod mix deps.compile
        MIX_ENV=test mix deps.compile

        tar czf cache.tgz _build deps
        mv cache.tgz _build
        ;;
    deps)
        CACHE_FROM=.deps/$MBS_ID-cache/cache.tgz
        if [ -f $CACHE_FROM ]; then
            echo "Using cached deps"
            tar xzf $CACHE_FROM
        else
            mix deps.get
        fi
        ;;
    compile)
        mix compile --warnings-as-errors
        ;;
    lint)
        # fmt
        mix format --check-formatted

        # xref_cycles
        CYCLES=$(mix xref graph --format=cycles)

        if [ "$CYCLES" != "No cycles found" ]; then
            echo "Found module dependency cycle:"
            echo "$CYCLES"
            exit 1
        fi

        # unused deps
        mix deps.unlock --check-unused

        # credo
        mix credo --all --strict

        # dialyzer
        if [ $DIALYZER == 1 ]; then
            if [ ! -f .plts/dialyzer.plt ]; then
                echo "Copying toolchain dialyzer.plt"
                mkdir -p .plts
                cp /dialyzer_plt/dialyzer.plt* .plts/
            fi

            mix dialyzer $DIALYZER_OPTS
        fi
        ;;
    test)
        mix coveralls
        ;;
    build)
        case $TYPE in
            lib)
                # Since we use "source dependencies" in our mix.exs deps
                # we don't actually need any artifact.
                # As a convention we output a "dummy" artifact, ie. the component checksum
                echo "$MBS_CHECKSUM" > _build/$MBS_ID
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
