FROM docker:20.10.5
RUN apk add --no-cache docker-compose
ADD build.sh /build.sh
ENTRYPOINT [ "/build.sh" ]
