FROM alpine:3.13.2
RUN apk add --no-cache docker-compose
ADD deploy.sh /deploy.sh
ENTRYPOINT [ "/deploy.sh" ]
