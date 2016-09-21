dir=$(dirname $(readlink -f "$0")) 
timestamp=`date +%Y-%m-%d-%H%M%S-%s`

repo=/var/scry
if [ ! -d "$repo" ]; then
  echo "$repo does not exist, abort."
  exit 1
fi

clientId=`jq -r .client_id /etc/scry/config.json`
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

echo 'Create snapshot.'
snapshot="${timestamp}.json.xz"
ruby "$dir/snapshot.rb" "$clientId" | xz -9 > "$snapshot"
mv "$snapshot" "$repo"

echo 'Finished.'
