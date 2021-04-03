#!/bin/sh

set -e

DIALYZER=0
DIALYZER_OPTS=""

args()
{
    options=$(
        getopt --long dialyzer --long dialyzer-opts: -- "$@"
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
        mix compile --warnings-as-errors
        ;;
    lint_fmt)
        mix format --check-formatted
        ;;
    lint_xref_cycles)
        CYCLES=$(mix xref graph --format=cycles)

        if [ "$CYCLES" != "No cycles found" ]; then
            echo "Found module dependency cycle:"
            echo "$CYCLES"
            exit 1
        fi
        ;;
    lint_credo)
        mix credo --all --strict
        ;;
    lint_dialyzer)
        if [ $DIALYZER == 1 ]; then
            mix dialyzer $DIALYZER_OPTS
        fi
        ;;
    test)
        mix coveralls
        ;;
    build)
        MIX_ENV=prod mix escript.build
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
