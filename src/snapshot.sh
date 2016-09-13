#!/bin/sh

base=/var/scry
if [ ! -d "$base" ]; then
  echo "$base does not exist, abort."
  exit 1
fi

cd "$base"
dir=`date +"%s"`
mkdir "$dir" && cd "$dir"

offset=0
count=0
retries=5
while true; do
  url="https://api.twitch.tv/kraken/streams?limit=100&offset=$offset"
  echo "Download $url."
  file="${count}.json"

  curl -s -o "$file" \
    -H 'Accept: application/vnd.twitchtv.v3+json' \
    -H 'Client-ID: Scry (https://github.com/schmich/scry)' \
    "$url"

  if [ $? -ne 0 ]; then
    retries=$((retries - 1))
    if [ $retries -eq 0 ]; then
      echo "Failed to download $url, abort."
      exit 1
    fi
    echo 'Download failed, try again.'
    sleep 5
    continue
  fi

  error=`jq '.error // empty' "$file"`
  if [ ! -z $error ]; then
    retries=$((retries - 1))
    if [ $retries -eq 0 ]; then
      echo "Failed to download $url, abort."
      exit 1
    fi
    echo 'Error in response, try again.'
    sleep 5
    continue
  fi

  retries=5
  offset=$((offset + 80))
  count=$((count + 1))

  streams=`jq '.streams | length' "$file"`
  if [ $streams -eq 0 ]; then
    break
  fi

  sleep 0.5
done

echo 'Compress snapshot.'
cd "$base"
tar -c "$dir" | xz -1 > "${dir}.tar.xz"
rm -rf "$dir"

echo 'Finished.'
