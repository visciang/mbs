FROM elixir:1.11.3-alpine AS builder
ENV MIX_ENV prod
RUN mix local.rebar --force
RUN mix local.hex --force
WORKDIR /mbs/
COPY mbs/config ./config
COPY mbs/lib ./lib
COPY mbs/test ./test
COPY mbs/mix.exs mbs/mix.lock ./
COPY mbs/.formatter.exs ./
RUN mix deps.get
RUN mix compile --warnings-as-errors
RUN mix escript.build

FROM elixir:1.11.3-alpine AS slim
RUN apk add --no-cache docker
COPY --from=builder /mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/mbs" ]

FROM elixir:1.11.3-alpine AS full
RUN apk add --no-cache docker graphviz
COPY --from=builder /mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/mbs" ]
