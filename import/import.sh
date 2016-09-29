#!/bin/sh

docker-compose -f docker-compose.yml -f docker-utils.yml run --rm mysql-runner /root/import.rb $*
