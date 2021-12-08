FROM elixir:1.13.0-alpine

RUN apk add --no-cache docker graphviz git
RUN mix local.rebar --force && mix local.hex --force
ADD toolchain.sh /toolchain.sh

ENTRYPOINT [ "/toolchain.sh" ]