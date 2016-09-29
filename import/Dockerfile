FROM alpine:3.4
MAINTAINER Chris Schmich <schmch@gmail.com>
RUN apk add --no-cache xz build-base ruby ruby-json ruby-dev mysql-dev
RUN gem install -N mysql2
ENTRYPOINT ["/usr/bin/ruby"]
