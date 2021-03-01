#!/bin/sh

set -e

case $1 in
    deps)
        mix deps.get
        ;;
    compile)
        mix compile --warnings-as-errors
        ;;
    lint)
        mix format --check-formatted
        mix credo --all --strict
        # mix dialyzer --plt
        # mix dialyzer --no-check
        ;;
    test)
        mix test
        # mix coveralls
        ;;
    build)
        mix escript.build
        ;;
    *)
        echo "bad target $1"
        exit 1
        ;;
esac
