FROM alpine:3.13.2
RUN apk add --no-cache curl jq
ADD toolchain.sh /toolchain.sh
ENTRYPOINT [ "/toolchain.sh" ]
