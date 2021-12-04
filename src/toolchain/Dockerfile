FROM elixir:1.12.3-alpine

RUN apk add --no-cache docker graphviz git
RUN mix local.rebar --force && mix local.hex --force
ADD toolchain.sh /toolchain.sh

ENTRYPOINT [ "/toolchain.sh" ]