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
# REF: https://github.com/docker-library/docker/blob/279ba9c93e8e26a15171645bd511ea8476c4706e/20.10/Dockerfile
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf
RUN wget -q -O - "https://download.docker.com/linux/static/stable/x86_64/docker-20.10.7.tgz" \
    | tar -xzf - --strip-components 1 --directory /usr/local/bin/
# USE https://github.com/docker/compose-cli when stable 
RUN apk add --no-cache "docker-compose>1.27"
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
