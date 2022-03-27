FROM elixir:1.13.3-alpine AS builder
ENV MIX_ENV prod
RUN apk add --no-cache git
RUN mix local.rebar --force
RUN mix local.hex --force
RUN mkdir /mbs /dask
COPY src/dask/mix.exs src/dask/mix.lock /dask/
RUN cd /dask && mix deps.get
COPY src/mbs/mix.exs src/mbs/mix.lock /mbs/
RUN cd /mbs && mix deps.get
COPY src/dask /dask
COPY src/mbs /mbs
WORKDIR /mbs
RUN mix compile --warnings-as-errors
RUN mix escript.build

FROM elixir:1.13.3-alpine
# REF: https://github.com/docker-library/docker/blob/279ba9c93e8e26a15171645bd511ea8476c4706e/20.10/Dockerfile
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf
RUN wget -q -O - "https://download.docker.com/linux/static/stable/x86_64/docker-20.10.14.tgz" \
    | tar -xzf - --strip-components 1 --directory /usr/local/bin/
RUN mkdir -p /usr/local/lib/docker/cli-plugins/ \
    && wget -q -O /usr/local/lib/docker/cli-plugins/docker-compose \
       "https://github.com/docker/compose/releases/download/v2.3.4/docker-compose-linux-x86_64" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
RUN apk add --no-cache graphviz git jq gettext
COPY dockerfiles/entrypoint.sh /entrypoint.sh
COPY dockerfiles/bootstrap.template.sh /bootstrap.template.sh
COPY --from=builder /mbs/mbs /usr/local/bin/
ARG MBS_VERSION=latest
ENV MBS_VERSION=${MBS_VERSION}
COPY dockerfiles/repo_init /repo_init
COPY mbs.sh /repo_init/
RUN sed -i "s/latest/$MBS_VERSION/g" /repo_init/mbs.sh
ENTRYPOINT [ "/entrypoint.sh" ]
