FROM elixir:1.11.4-alpine

RUN mix local.rebar --force && mix local.hex --force
ADD build.sh /toolchain/build.sh

ENTRYPOINT [ "/toolchain/build.sh" ]