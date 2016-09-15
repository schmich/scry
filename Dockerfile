FROM alpine:3.4
MAINTAINER Chris Schmich <schmch@gmail.com>
RUN echo @testing http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
 && echo @testing http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories
RUN apk add --no-cache jq curl xz ca-certificates moreutils@testing
COPY crontab /var/spool/cron/crontabs/root
COPY src /srv/scry
ENTRYPOINT ["/usr/sbin/crond", "-f"]
