FROM elixir:1.11.4-alpine

RUN apk add --no-cache docker docker-compose graphviz git
RUN mix local.rebar --force && mix local.hex --force
ADD toolchain.sh /toolchain.sh

ENTRYPOINT [ "/toolchain.sh" ]