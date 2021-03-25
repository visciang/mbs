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

FROM elixir:1.11.4-alpine AS slim
RUN apk add --no-cache docker git
COPY dockerfiles/entrypoint.sh /entrypoint.sh
COPY --from=builder /mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/entrypoint.sh" ]

FROM elixir:1.11.4-alpine AS full
RUN apk add --no-cache docker git graphviz
COPY dockerfiles/entrypoint.sh /entrypoint.sh
COPY --from=builder /mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/entrypoint.sh" ]
