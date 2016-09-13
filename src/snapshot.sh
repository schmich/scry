#!/bin/sh

base=/var/scry
if [ ! -d "$base" ]; then
  echo "$base does not exist, exiting."
  exit 1
fi

cd "$base"
dir=`date +"%s"`
mkdir "$dir" && cd "$dir"

offset=0
count=0
while true; do
  url="https://api.twitch.tv/kraken/streams?limit=100&offset=$offset"
  echo "Downloading $url."
  file="${count}.json"
  curl -s -o "$file" -H 'Accept: application/vnd.twitchtv.v3+json' "$url"
  if [ $? -ne 0 ]; then
    echo 'Download failed, trying again.'
    sleep 5
    continue
  fi
  offset=$((offset + 80))
  count=$((count + 1))
  stream_count=`jq '.streams | length' "$file"`
  if [ $stream_count -eq 0 ]; then
    break
  fi
  sleep 0.5
done

echo 'Compress snapshot.'
cd "$base"
tar -c "$dir" | xz -1 > "${dir}.tar.xz"
rm -rf "$dir"

echo 'Finished.'
