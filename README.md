<div align="center">

# QuakeJS Rootless Project

## Play multiplayer Quake III Arena in your browser with Podman / Docker

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-awakenedpower%2Fquakejs--rootless-blue?style=for-the-badge&logo=docker)](https://hub.docker.com/r/awakenedpower/quakejs-rootless)

</div>

## About

This project is a fully local QuakeJS server fork based on @treyyoder's original repository. The primary goal of this fork is to deliver a modern, lightweight, and secure alternative. 
To achieve this, the original game code was refactored to support modern npm packages, resulting in a meaningful reduction of critical and high-severity vulnerabilities.

| Component | This Fork |
|-----------|-----------|
| Base OS | **Debian 13 Docker Hardened Image** |
| Node.js | **22.x LTS** |
| Web Server | **Nginx Light** |
| Networking | **Single Port Multiplexed via Nginx** |
| Container User | **non-root** |
| npm packages | **Modernized, with compatibility fixes** |

<details>
<summary><b>What "modernized" means</b></summary>

The QuakeJS server and tooling were written against Node 0.10-era packages, five
of which are now unmaintained. They have been removed in favour of Node natives
or maintained equivalents, and the two upgrades that changed public APIs were
followed through in the calling code:

| Was | Now | Notes |
|---|---|---|
| `optimist` | `yargs` 18 | argument parsing across all `bin/` entry points |
| `wrench` | native `fs` | recursive `readdirSync`, `mkdirSync`, `rmSync` |
| `execSync` (package) | native `spawnSync` | shimmed to keep the old `{code, stdout}` return shape |
| `temp` | native `fs.mkdtempSync` | |
| `express` 3.3 | `express` 5.2 | `res.sendfile` → `res.sendFile`; `express.compress` replaced by the standalone `compression` package |
| `ws` 0.4 | `ws` 8.21 | `upgradeReq` replaced by the handler's `req` argument; `flags.binary` → `isBinary` |

Also bumped: async, buffer-crc32, ejs, send, underscore, winston.

The `ws` change is the only one that reaches into GPL-covered engine code; see
[Licensing](#licensing).

</details>

### Out of Scope
- Recompile original game code from ioquake3 (still old game code)
- Introduce new functionality

## Quick Start

### Using Podman (Recommended)

```bash
podman run -d \
  --name quakejs \
  -p 8080:8080 \
  docker.io/awakenedpower/quakejs-rootless:latest
```

### Using Docker Run

```bash
docker run -d \
  --name quakejs \
  -p 8080:8080 \
  docker.io/awakenedpower/quakejs-rootless:latest
```

Then open your browser and navigate to `http://localhost:8080` to start playing!

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
services:
  quakejs:
    container_name: quakejs
    image: awakenedpower/quakejs-rootless:latest
    ports:
      - '8080:8080'
    restart: unless-stopped
```

Then run:

```bash
docker-compose up -d
```

### Using Kubernetes with Helm

This repository includes a Helm chart in `.helm/`. The CI workflow builds and pushes a `linux/amd64` image, then packages the chart as an OCI artifact with the image pinned as `tag@sha256:<digest>`.

Local install:

```bash
helm install quake .helm \
  --namespace quakejs \
  --create-namespace
```

Install from the published OCI Helm chart:

```bash
helm install quake oci://ghcr.io/jackbrenn/quakejs-rootless/helm/quake \
  --namespace quakejs \
  --create-namespace
```

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
    targetRevision: 0.1.0
    helm:
      values: |
        ingress:
          enabled: true
          className: ""
          hosts:
            - host: quake.example.com
              tls: false
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

Important values:

```yaml
image:
  repository: docker.io/awakenedpower/quakejs-rootless
  tag: latest

ingress:
  enabled: false
  className: ""
  hosts:
    - host: quake.example.com
      tls: false

quake:
  fsGame: baseq3
```

For ArgoCD, consume the published OCI Helm chart and override values there rather than editing rendered manifests.

## Building from Source

### Building with Podman (Recommended)
You must login to dhi.io (Free with a Dockerhub user) to download the hardened images.

1. **Clone the repository:**
```bash
git clone https://github.com/JackBrenn/quakejs-rootless.git
cd quakejs-rootless
```

2. **Build the image:**

```bash
podman login dhi.io
podman build -t quakejs-rootless:latest .
```

3. **Run the container:**
```bash
podman run -d \
  --name quakejs \
  -p 8080:8080 \
  quakejs-rootless:latest
```

### Building with Docker

1. **Clone the repository:**
```bash
git clone https://github.com/JackBrenn/quakejs-rootless.git
cd quakejs-rootless
```
2. **Build the image:**
```bash
docker login dhi.io
docker build -t quakejs-rootless:latest .
```

3. **Run the container:**
```bash
docker run -d \
  --name quakejs \
  -p 8080:8080 \
  quakejs-rootless:latest
```

## Configuration

### Server Configuration

The server configuration can be customized by modifying `server.cfg`.

### Ports

- **8080** - Multiplexed Web interface and Game server port. Web requests are handled by Nginx directly, while WebSocket game traffic is seamlessly forwarded internally. This makes proxying behind SSL natively supported via a single port.

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
| `quakejs/bin/`, `quakejs/html/` (except `ioquake3.js`), `quakejs/base/`, `quakejs/package.json` | QuakeJS (Anthony Pesch), with changes from this repository | MIT |
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

**`quakejs/html/ioquake3.js`**

1. The same `ws` 8.x `isBinary` change as above. Made in this repository.

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
