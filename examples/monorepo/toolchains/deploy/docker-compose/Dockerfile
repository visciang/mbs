FROM alpine:3.13.2
RUN apk add --no-cache docker-compose
ADD toolchain.sh /toolchain.sh
ENTRYPOINT [ "/toolchain.sh" ]
