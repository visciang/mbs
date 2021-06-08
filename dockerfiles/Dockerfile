FROM elixir:1.12.1-alpine AS builder
ENV MIX_ENV prod
RUN mix local.rebar --force
RUN mix local.hex --force
RUN mkdir /mbs /dask
COPY src/mbs/mix.exs src/mbs/mix.lock /mbs/
RUN cd /mbs && mix deps.get
COPY src/dask/mix.exs src/dask/mix.lock /dask/
RUN cd /dask && mix deps.get
COPY src/dask /dask
COPY src/mbs /mbs
WORKDIR /mbs
RUN mix compile --warnings-as-errors
RUN mix escript.build

FROM elixir:1.12.1-alpine
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf
RUN apk add --no-cache graphviz git jq gettext
RUN apk add --no-cache "docker>20.10" "docker-compose>1.27"
COPY dockerfiles/entrypoint.sh /entrypoint.sh
COPY dockerfiles/bootstrap.template.sh /bootstrap.template.sh
COPY --from=builder /mbs/mbs /usr/local/bin/
ARG MBS_VERSION=latest
ENV MBS_VERSION=${MBS_VERSION}
COPY dockerfiles/repo_init /repo_init
COPY mbs.sh /repo_init/
RUN sed -i "s/latest/$MBS_VERSION/g" /repo_init/mbs.sh
ENTRYPOINT [ "/entrypoint.sh" ]
