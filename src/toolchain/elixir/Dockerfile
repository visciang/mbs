FROM elixir:1.13.0-alpine

RUN apk add --no-cache docker graphviz git
RUN mix local.rebar --force && mix local.hex --force
ADD dialyzer_plt /dialyzer_plt
RUN cd /dialyzer_plt \
    && mix deps.get \
    && mix dialyzer --plt
ADD toolchain.sh /toolchain.sh

ENTRYPOINT [ "/toolchain.sh" ]