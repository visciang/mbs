FROM elixir:1.11.3-alpine AS builder
ENV MIX_ENV prod
RUN mix local.rebar --force
RUN mix local.hex --force
COPY mbs /mbs
WORKDIR /mbs/
RUN mix deps.get
RUN mix compile --warnings-as-errors
RUN mix escript.build

FROM elixir:1.11.3-alpine AS slim
COPY --from=builder /mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/mbs" ]

FROM elixir:1.11.3-alpine as full
RUN apk add --no-cache graphviz
COPY --from=builder /mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/mbs" ]
