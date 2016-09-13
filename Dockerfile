FROM alpine:3.4
MAINTAINER Chris Schmich <schmch@gmail.com>
RUN apk add --no-cache jq curl xz ca-certificates
RUN curl -L -o /bin/gdrive 'https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download' \
 && chmod +x /bin/gdrive
COPY crontab /var/spool/cron/crontabs/root
COPY src /srv/scry
ENTRYPOINT ["/usr/sbin/crond", "-f"]
