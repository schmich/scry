FROM alpine:3.4
MAINTAINER Chris Schmich <schmch@gmail.com>
RUN apk add --no-cache jq curl xz ca-certificates
COPY crontab /var/spool/cron/crontabs/root
COPY src /srv/scry
ENTRYPOINT ["/usr/sbin/crond", "-f"]
