FROM elixir:1.11.3-alpine AS builder

ENV MIX_ENV prod
RUN mix local.rebar --force
RUN mix local.hex --force
RUN mkdir /build
COPY workflow /build/workflow
COPY mbs /build/mbs
WORKDIR /build/mbs/
RUN mix deps.get
RUN mix compile --warnings-as-errors
RUN mix escript.build


FROM elixir:1.11.3-alpine

COPY --from=builder /build/mbs/mbs /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/mbs" ]