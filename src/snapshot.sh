#!/bin/sh

repo=/var/scry
if [ ! -d "$repo" ]; then
  echo "$repo does not exist, abort."
  exit 1
fi

clientId=`jq -r .clientId /etc/scry/config.json`
if [ -z "$clientId" ]; then
  echo 'Client ID not specified, abort.'
  exit 1
fi

tmp=`mktemp -d`
if [ $? -ne 0 ]; then
  echo 'Could not create temp directory.'
  exit 1
fi
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
timestamp=`date +%Y-%m-%d-%H%M%S-%s`
mkdir "$timestamp" && cd "$timestamp"

offset=0
count=0
retries=10
while true; do
  url="https://api.twitch.tv/kraken/streams?limit=100&offset=$offset"
  echo "Download $url."
  file="${count}.json"

  snapshotAt=`date +%s`
  timeout 5 curl -s -o "$file" \
    -H 'Accept: application/vnd.twitchtv.v3+json' \
    -H "Client-ID: $clientId" \
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

  error=`jq -r '.error // empty' "$file"`
  if [ ! -z "$error" ]; then
    retries=$((retries - 1))
    if [ $retries -eq 0 ]; then
      echo "Failed to download $url, abort."
      exit 1
    fi
    echo 'Error in response, try again.'
    sleep 5
    continue
  fi

  jq -c --argjson snapshot_at $snapshotAt \
    '. * { snapshot_at: $snapshot_at }' "$file" | sponge "$file"

  retries=10
  offset=$((offset + 80))
  count=$((count + 1))

  streams=`jq '.streams | length' "$file"`
  if [ $streams -eq 0 ]; then
    break
  fi

  sleep 0.5
done

echo 'Compress snapshot.'
cd "$tmp"
snapshot="${timestamp}.tar.xz"
tar -c "$timestamp" | xz -1 > "$snapshot"
mv "$snapshot" "$repo"

echo 'Finished.'
