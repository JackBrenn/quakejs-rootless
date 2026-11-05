# QuakeJS Rootless

Multiplayer Quake III Arena in the browser, served from one rootless container.
A fork of [treyyoder/quakejs-docker](https://github.com/treyyoder/quakejs-docker).

- Debian 13 Docker Hardened Image, Node.js 24 LTS and nginx-light
- Runs as a non-root user
- One port (8080) serves the web client, the game data and the WebSocket game traffic

## Run

Images are published to GHCR and can be pulled anonymously:

```bash
podman run -d --name quakejs -p 8080:8080 ghcr.io/jackbrenn/quakejs-rootless:latest
```

Then open <http://localhost:8080>. `docker run` takes the same arguments, and
`docker compose up -d` uses this repository's [`docker-compose.yml`](docker-compose.yml).

## Kubernetes (Helm)

Each release publishes the chart in `.helm/` as an OCI artifact, with the image
pinned by digest:

```bash
helm install quake oci://ghcr.io/jackbrenn/quakejs-rootless/helm/quake \
  --namespace quakejs --create-namespace
```

The main values (see [`.helm/values.yaml`](.helm/values.yaml) for the rest):

```yaml
ingress:
  enabled: true
  className: ""
  hosts:
    - host: quake.example.com
  tls: []            # e.g. [{secretName: quake-tls, hosts: [quake.example.com]}]

quake:
  fsGame: baseq3     # or cpma
  serverConfig: ""   # set to replace the image's server.cfg
```

The pod runs with a read-only root filesystem; the game server downloads its
game data into an `emptyDir` when it starts.

## Configuration

- **`server.cfg`**: the server settings. Edit it and rebuild, or mount your own
  over `/etc/quakejs/server.cfg`.
- **`FS_GAME`**: `baseq3` (default) or `cpma`.
- **Port 8080** is the only port, so it is all a TLS reverse proxy needs.

## Build

Pulling the hardened base images needs a dhi.io login (free with a Docker Hub
account). The commands are the same with `docker`.

```bash
podman login dhi.io
podman build -t quakejs-rootless .
```

`test/smoke.sh` builds the image, runs it and checks that it serves the game.

## Licensing

The project as distributed, images included, is a combined work under the GNU
GPL, version 2 or later ([`COPYING`](COPYING)). The packaging in this
repository is also available under MIT; [`LICENSE.MIT`](LICENSE.MIT) lists the
files it covers. The two engine builds, `quakejs/build/ioq3ded.js` and
`quakejs/html/ioquake3.js`, list their changes and corresponding source in
their headers.

The game data in `include/assets/` is not free software and not under the GPL:
the Quake III Arena demo, under id Software's demo licence (non-commercial
redistribution only, and running this container means accepting it); the 1.32b
point release; and third-party maps and mods under their authors' terms. Do not
add retail `.pk3` files to an image you publish.

## Credits

- [@inolen](https://github.com/inolen): [QuakeJS](https://github.com/inolen/quakejs)
- [@nerosketch](https://github.com/nerosketch): [QuakeJS fork](https://github.com/nerosketch/quakejs) with local server support
- [@treyyoder](https://github.com/treyyoder): [quakejs-docker](https://github.com/treyyoder/quakejs-docker)
- [@mescanne](https://github.com/mescanne): single-port nginx WebSocket routing
- [@jonasbg](https://github.com/jonasbg): Helm chart and OCI publishing
