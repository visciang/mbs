#!/bin/sh

set -e

mix local.rebar --force
mix local.hex --force

mix deps.get
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --all --strict
# mix dialyzer --plt
# mix dialyzer --no-check
# mix coveralls
mix test
mix escript.build