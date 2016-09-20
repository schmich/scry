# Scry

Track Twitch global stream stats.

## Running

Twitch requires a Client ID for all API requests. [Register your app with Twitch](https://www.twitch.tv/kraken/oauth2/clients/new) to get a Client ID.

```bash
mkdir /srv/scry
echo '{ "client_id": "your-twitch-client-id" }' > /srv/scry/config.json
docker run --restart always -d -v /srv/scry:/var/scry -v /srv/scry:/etc/scry schmich/scry:latest
# You can pick a stable tag from https://hub.docker.com/r/schmich/scry/tags
```

## License

Copyright &copy; 2016 Chris Schmich  
MIT License. See [LICENSE](LICENSE) for details.
