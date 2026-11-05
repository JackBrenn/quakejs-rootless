<div align="center">

# QuakeJS Rootless Project

## Play multiplayer Quake III Arena in your browser with Podman / Docker

[![GitHub Container Registry](https://img.shields.io/badge/GHCR-jackbrenn%2Fquakejs--rootless-blue?style=for-the-badge&logo=github)](https://github.com/JackBrenn/quakejs-rootless/pkgs/container/quakejs-rootless)

</div>

## About

A fully local QuakeJS server, forked from @treyyoder's quakejs-docker and
packaged as a small, rootless container.

| Component | |
|-----------|-----------|
| Base OS | **Debian 13 Docker Hardened Image** |
| Node.js | **24.x LTS** |
| Web Server | **Nginx Light** |
| Networking | **Single Port Multiplexed via Nginx** |
| Container User | **non-root** |

The server's only npm dependency is `ws` 8. Moving to it from `ws` 0.4 needed
one change to GPL-covered engine code; see [Licensing](#licensing).

Out of scope: recompiling the engine from ioquake3, and adding new features.

## Quick Start

Images are published to **GitHub Container Registry** by this repository's
release workflow and can be pulled anonymously. A Docker Hub mirror,
[`awakenedpower/quakejs-rootless`](https://hub.docker.com/r/awakenedpower/quakejs-rootless),
is published by hand outside this repository; prefer GHCR.

```bash
podman run -d --name quakejs -p 8080:8080 ghcr.io/jackbrenn/quakejs-rootless:latest
```

`docker run` takes the same arguments. Then open `http://localhost:8080` to play.

With Compose, use this repository's [`docker-compose.yml`](docker-compose.yml):

```bash
docker compose up -d
```

### Kubernetes with Helm

Each release publishes the chart in `.helm/` as an OCI artifact, with the
image pinned as `version@sha256:<digest>`. To install from a checkout instead,
use `.helm` as the chart.

```bash
helm install quake oci://ghcr.io/jackbrenn/quakejs-rootless/helm/quake \
  --namespace quakejs --create-namespace
```

The main values:

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

The pod runs as a non-root user with a read-only root filesystem; the game
server downloads its game data into an `emptyDir` when it starts.

<details>
<summary>ArgoCD Application example</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: quake
  namespace: argocd
spec:
  project: default
  source:
    repoURL: oci://ghcr.io/jackbrenn/quakejs-rootless/helm
    chart: quake
    targetRevision: 2.0.0
    helm:
      values: |
        ingress:
          enabled: true
          hosts:
            - host: quake.example.com
  destination:
    server: https://kubernetes.default.svc
    namespace: quakejs
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

</details>

## Building from Source

You need to log in to dhi.io (free with a Docker Hub account) to pull the
hardened base images. The commands are the same with `docker`.

```bash
git clone https://github.com/JackBrenn/quakejs-rootless.git
cd quakejs-rootless
podman login dhi.io
podman build -t quakejs-rootless .
```

`test/smoke.sh` builds the image, runs it and checks that it serves the game.

## Configuration

- **`server.cfg`**: the server settings. Edit it and rebuild, or mount your own
  over `/etc/quakejs/server.cfg`.
- **`FS_GAME`**: `baseq3` (default) or `cpma`.
- **Port 8080**: serves the web client and forwards WebSocket game traffic to
  the game server inside the container, so one port is all a TLS reverse proxy
  needs.

## Credits & Acknowledgments
This wouldn't be possible without these projects or contributors:
- **[@jonasbg](https://github.com/jonasbg)** - Hardened Kubernetes Helm chart and OCI publishing workflow
- **[@treyyoder](https://github.com/treyyoder)** - Original [quakejs-docker](https://github.com/treyyoder/quakejs-docker) implementation that made fully local QuakeJS servers possible
- **[@nerosketch](https://github.com/nerosketch)** - [QuakeJS fork](https://github.com/nerosketch/quakejs.git) with local server capabilities
- **[@inolen](https://github.com/inolen)** - Original [QuakeJS](https://github.com/inolen/quakejs) project
- **[@mescanne](https://github.com/mescanne)** - Single-port multiplexing concept via Nginx WebSocket routing

## Licensing

This repository packages the Quake III Arena engine, which is free software, and
ships it alongside game content, which is not. The two have different terms.

**The project as distributed — including any container image built from it — is a
combined work covered by the GNU General Public License, version 2 or later**
(`COPYING`). The original packaging work in this repository is *additionally*
available under the MIT licence (`LICENSE.MIT`), so you may take those files
under either licence at your option.

| Component | Origin | Licence |
|---|---|---|
| `quakejs/build/ioq3ded.js`, `quakejs/html/ioquake3.js` | id Software → ioquake3 → QuakeJS (Emscripten build) | GPL-2.0-or-later |
| `quakejs/html/` (except `ioquake3.js`), `quakejs/package.json` | QuakeJS (Anthony Pesch), with changes from this repository | MIT |
| `Dockerfile`, `entrypoint.sh`, `nginx.conf`, `server.cfg`, `.helm/`, `.github/workflows/` | This repository | MIT (`LICENSE.MIT`) |
| `include/assets/` | id Software and third-party map/mod authors | Proprietary — see [Game content](#game-content) |

### Provenance of the engine

id Software released the Quake III Arena source under the GPL, version 2 or
later. [ioquake3](https://github.com/ioquake/ioq3) continues that codebase under
the same terms. [QuakeJS](https://github.com/inolen/quakejs) compiles it to
JavaScript with Emscripten. This repository is a fork of
[treyyoder/quakejs-docker](https://github.com/treyyoder/quakejs-docker), which
forked [nerosketch/quakejs](https://github.com/nerosketch/quakejs), which forked
QuakeJS. The compiled JavaScript is engine-derived and carries the GPL with it,
regardless of what licence sits on the JavaScript wrapper around it.

### Source code for the engine

The `.js` engine builds in this repository are compiled output. Their
corresponding source is the Emscripten-patched ioquake3 tree that QuakeJS builds
from:

- <https://github.com/inolen/ioq3> — submodule of upstream QuakeJS
- <https://github.com/begleysm/ioq3> — submodule of the nerosketch fork this tree descends from

This notice, together with the patch list below, is intended to satisfy the
source-availability requirement of GPLv2 section 3 for the images published to
Docker Hub and ghcr.io as well as for the repository itself. If you receive an
image without this README, the corresponding source is at
<https://github.com/JackBrenn/quakejs-rootless>.

### Modifications to GPL-covered files

GPLv2 section 2(a) requires modified files to carry notice of the change. The
compiled engine files in this tree differ from upstream QuakeJS as follows:

**`quakejs/build/ioq3ded.js`**

1. The interactive demo EULA prompt in `PromptEULA` is replaced with a printed
   notice and an immediate callback, so the dedicated server starts without
   requiring terminal input. Inherited from `treyyoder/quakejs-docker`
   (`include/ioq3ded/ioq3ded.fixed.js`). See [Game content](#game-content) —
   running this container still means accepting id Software's demo terms.
2. The WebSocket message handler is updated from the `flags.binary` argument of
   `ws` 1.x to the `isBinary` argument used by `ws` 8.x. Made in this repository
   as part of the dependency modernisation.
3. The WebSocket server caps incoming messages at 64 KiB instead of the `ws`
   default of 100 MiB. Made in this repository.

**`quakejs/html/ioquake3.js`**

1. The same `ws` 8.x `isBinary` change as above. Made in this repository.
2. The three hardcoded `http://`/`ws://` URL literals use the page's own
   protocol instead, so clients served over TLS fetch assets and connect over
   `https:`/`wss:`. Made in this repository.

No other changes have been made to engine-derived files.

### Game content

**The Quake III Arena game data is not free software and is not covered by the
GPL.** The engine is; the art, models, sounds and maps are not. What ships in
`include/assets/` is:

- **The Quake III Arena demo installer** (`linuxq3ademo-1.11-6.x86.gz.sh`),
  distributed under id Software's limited-use demo licence agreement. That
  agreement permits non-commercial redistribution of the unmodified demo; it does
  not grant rights to the retail game.
- **The Quake III Arena 1.32b point release** (`linuxq3apoint-1.32b-3.x86.run`),
  id Software's patch distribution.
- **Third-party maps and mods** — Threewave CTF (`q3wctf1`–`q3wctf3`), Rocket
  Arena 3 (`ra3map1`, `ra3map11`, `ra3map12`), `ztn3tourney1`, and Challenge
  ProMode Arena (`cpma/`) — each under its author's own terms, which are
  generally free non-commercial redistribution but are neither GPL nor id's.
- **Repacked common assets** (`pak100.pk3`, `pak101.pk3`) generated upstream by
  the QuakeJS `repak` tool from the above, and inheriting their terms.

**Do not add retail `pak0.pk3` or other retail `.pk3` files to an image you
publish.** Owning the game does not give you the right to redistribute its data.
If you want retail content on your own server, install it yourself from your own
copy.

If you are a rights holder for any content bundled here and would like it
removed, please open a PR.
