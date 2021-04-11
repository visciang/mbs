FROM elixir:1.11.4-alpine AS builder
ENV MIX_ENV prod
RUN mix local.rebar --force
RUN mix local.hex --force
WORKDIR /mbs/
COPY mbs/mix.exs mbs/mix.lock ./
RUN mix deps.get
COPY mbs/config ./config
COPY mbs/lib ./lib
COPY mbs/test ./test
COPY mbs/.formatter.exs ./
RUN mix compile --warnings-as-errors
RUN mix escript.build

FROM elixir:1.11.4-alpine
RUN apk add --no-cache docker docker-compose graphviz git
COPY dockerfiles/entrypoint.sh /entrypoint.sh
COPY --from=builder /mbs/mbs /usr/local/bin/
ARG MBS_VERSION=latest
ENV MBS_VERSION=${MBS_VERSION}
COPY examples/repo_init /repo_init
COPY mbs.sh mbs.fish /repo_init/
RUN sed -i "s/latest/$MBS_VERSION/g" /repo_init/mbs.sh
RUN sed -i "s/latest/$MBS_VERSION/g" /repo_init/mbs.fish
ENTRYPOINT [ "/entrypoint.sh" ]
