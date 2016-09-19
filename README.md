# Scry

Track Twitch global stream stats.

## Running

```bash
mkdir /srv/scry
docker run --restart always -d -v /srv/scry:/var/scry -v /srv/scry:/etc/scry schmich/scry:latest
# You can pick a stable tag from https://hub.docker.com/r/schmich/scry/tags
```

## License

Copyright &copy; 2016 Chris Schmich  
MIT License. See [LICENSE](LICENSE) for details.
