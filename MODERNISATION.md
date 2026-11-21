# Modernisation plan: QuakeJS engine → current ioquake3

Working document for this repository. Delete it when the work merges back
into quakejs-rootless.

## Goal

Replace the two prebuilt engine files inherited from QuakeJS (a 2013
Emscripten/asm.js build of an ioquake3 fork) with engines compiled from
current [ioquake/ioq3](https://github.com/ioquake/ioq3) source inside the
image build. Everything the image does today stays: one rootless container,
one port (8080), browser client, multiplayer over WebSocket, `FS_GAME`
baseq3/cpma, Helm chart.

Net effect on the repository: about 51,800 lines of generated JavaScript
(`quakejs/html/ioquake3.js`, `quakejs/build/ioq3ded.js`) are deleted and
replaced by a pinned upstream commit, a small web shell and a small
WebSocket-to-UDP bridge.

## Working rules (carried over from quakejs-rootless)

- Less code is the goal. Prefer deleting to adding; every addition must earn
  its place.
- Work on a branch, test locally, push only when explicitly authorised.
- No contact details or email addresses anywhere in the repository.

## What upstream gives us, and what it does not

Read from ioq3 at commit `52088b9` (2026-11-04) and Emscripten `main`.

| Area | Upstream ioquake3 today |
|---|---|
| Build system | CMake. `emcmake cmake -S . -B build && cmake --build build` produces `ioquake3.js`, `ioquake3.wasm`, an HTML shell and the game QVMs. Upstream CI builds this on every commit (emsdk 3.1.58). |
| Web client | WebAssembly, SDL2, the opengl2 renderer on WebGL 1/2. Fixed 256 MB heap. |
| Web networking | **Off.** The shell passes `+set net_enabled 0` and `+set sv_pure 0`. Single-player only. |
| Web dedicated server | **Not built.** `BUILD_SERVER` is forced off for Emscripten. |
| Game data in the browser | The shell fetches every file listed in a JSON config into an in-memory filesystem before the engine starts. No on-demand downloads (`USE_HTTP` is forced off), no caching beyond the browser's HTTP cache, no saved settings. |
| Data checks | Without all of `baseq3/pak0..8.pk3` the engine refuses to start. The demo `pak0.pk3` is accepted only from a `demoq3/` directory. The demo's own QVMs are incompatible. |

So the heavy lifting is networking and game data, not the compile.

Networking looks tractable without engine patches. Emscripten emulates UDP
sockets over WebSockets: each `sendto()` destination becomes a WebSocket,
`Module.websocket.url` can pin every destination to one URL (ours: the page's
own origin), and non-blocking mode (`FIONBIO`) is supported. The engine's
`net_ip.c` uses only those calls on the client path. This is read from
source, **not yet run**; phase 1 exists to prove or disprove it.

## Target architecture

```
browser ── https/wss :8080 ──> nginx ──┬─ static: shell, ioquake3.js/.wasm, game data
                                       └─ WebSocket ──> bridge ── UDP 127.0.0.1:27960 ──> ioq3ded (native)
```

- **Client**: ioquake3 compiled to WebAssembly in a build stage, from a
  pinned upstream commit. Any engine changes live as patch files in
  `patches/` (target: none, or only what phase 1 proves necessary).
- **Server**: the native Linux `ioq3ded`, compiled in a build stage from the
  same commit. No longer JavaScript, no longer patched. Bound to loopback.
- **Bridge**: one WebSocket connection ↔ one UDP socket; each binary message
  is one datagram. About 40 lines of Node using the `ws` package the image
  already ships. It drops Emscripten's 10-byte `port` hello message and caps
  message size as the current server does. Players appear to the server as
  127.0.0.1 with distinct ports, as they effectively do today.
- **Game code**: QVMs built from ioquake3 source in the same build, packed
  into a pk3 that outranks the demo's QVMs. CPMA keeps its own QVMs.
- **nginx, entrypoint, Helm, CI**: same shape as today, adjusted.

## Phases

Each phase ends in something that runs. Phases 1 and 2 are the risky ones.

### 0. Baseline — done

Repository copied with history (`main` = quakejs-rootless `master` at
`908ff75`, no tags). Work happens on the `ioq3-modernisation` branch.

### 1. Spike: prove the transport (throwaway)

Outside the image, with podman: build the web client with an `emsdk`
container and `ioq3ded` natively at one pinned commit; hand-write the bridge;
serve the demo and point-release paks; join the server from a browser.

- Done when: a browser joins a map on the native server over WebSocket and
  plays, and a second browser can join it.
- Produces: the emsdk version to pin, the exact list of engine patches (if
  any), the working data layout, and a go/no-go on the "no patches" hope.
- If Emscripten's socket emulation falls short: fall back to a small
  Emscripten-only net backend in the client (WebSocket API directly). That
  is a patch of roughly 100–150 lines we would carry.

### 2. Build the engines in the Dockerfile

- New build stages: web client (emsdk image pinned by digest), native server
  (existing hardened dev image), QVM pk3.
- Delete `quakejs/html/ioquake3.js`, `quakejs/build/ioq3ded.js`,
  `quakejs/html/game.css` and whatever else only the old engine used.
- Done when: `podman build` produces an image containing engines built from
  the pinned commit and nothing prebuilt.

### 3. Game data

- Layout the stock engine accepts: `demoq3/pak0.pk3` (demo, via
  `fs_basegame demoq3`), `baseq3/pak1..8.pk3` (point release), the existing
  gap-filler and map paks, `cpma/*`.
- Keep today's licence posture: the image ships id's installers intact; the
  server unpacks them at container start; the browser downloads the
  installers and unpacks them locally after the player accepts the demo
  EULA (`DecompressionStream` plus a minimal tar reader, about 40 lines).
- Replace `manifest.json` and the checksum-prefixed file names with the
  plain file list the new shell reads.
- Done when: baseq3 and cpma both start on the server and in the browser
  from an image that contains only the original installers and paks.

### 4. Web shell

Our own `index.html` and `main.js` (upstream's shell is a demo page with an
inline script, which the CSP forbids):

- EULA screen with the source link (GPLv2 §3), download progress, start.
- Query-string parameters become console commands, as now.
- Connects to the page's own origin; `ws:`/`wss:` follows the page.
- CSP tightened from `'unsafe-eval'` to `'wasm-unsafe-eval'`; nginx gzips
  `.wasm`.
- Done when: a first-time visitor gets from URL to in-game with one click.

### 5. Runtime, tests, docs

- Entrypoint runs nginx, the bridge and `ioq3ded`; any one exiting stops the
  container. Read-only root filesystem keeps working; the server's home
  directory moves to the writable volume.
- `test/smoke.sh` keeps its checks (the `getstatus`-over-WebSocket probe
  works unchanged against the bridge) and gains a check that the `.wasm` is
  served with the right type.
- Helm volumes, README and licence text updated: corresponding source is
  the pinned ioquake3 commit plus `patches/`.
- Done when: smoke test passes with podman and docker, `helm lint` passes.

### 6. Parity and polish

Compare against the current image, item by item:

| Feature today | Plan |
|---|---|
| Maps fetched when needed | Phase 3 fetches everything for the `fs_game` up front (about 190 MB for baseq3, of which about 107 MB is custom maps the default rotation never loads). Then either drop the unused maps from the default list or add an Emscripten backend for the engine's existing HTTP download hook (`cl_http.h`, about 100 lines, upstreamable). |
| Assets cached in IndexedDB | Browser HTTP cache with revalidation. Add IndexedDB only if large files prove not to cache. |
| Player settings persist | Not provided by upstream. Add an IDBFS mount for the home directory if wanted. |
| Bots | Verify; upstream warns the demo's bot files do not fully match newer QVMs. |
| CPMA | Verify the shipped CPMA version runs on current ioquake3. |
| Pure server | Aim for `sv_pure 1` since client and server load identical paks. |

### 7. Merge back

Bring the branch into quakejs-rootless as a major version (v3.0.0): branch
there, branch CI green on Docker, authorised push, merge.

## Decisions needed (recommendation first)

1. **Demo licence handling** — keep the installers intact and unpack in the
   browser after the EULA, as today. Alternative: unpack at image build and
   serve pk3 files directly; simpler, but it changes how id's demo is
   redistributed.
2. **Pinning ioquake3** — a commit SHA and checksum in the Dockerfile; a
   bump is a one-line change that CI tests. Alternative: a git submodule,
   which Dependabot can bump on its own but which every clone and CI
   checkout must then handle.
3. **Game code** — build QVMs from ioquake3 source (current fixes).
   Alternative: keep id's 2001 QVMs from the point release.
4. **Bridge runtime** — Node, since the image already carries Node and `ws`.
   Once it works, evaluate replacing Node entirely with a packaged static
   bridge such as `websocat`, which would remove Node from the final image.
5. **emsdk image** — `emscripten/emsdk` pinned by digest, build stage only.
   It is not a Docker Hardened Image; nothing from it ships except the
   compiled client.

## Risks

- **Browser networking is unproven upstream.** It is disabled there on
  purpose. Phase 1 settles it before anything else is built.
- **Renderer change.** opengl2 on WebGL replaces QuakeJS's renderer;
  upstream describes its GLES path as feature-incomplete and possibly slow
  on weak GPUs. Check visuals and frame rate early in phase 1.
- **Memory.** Fixed 256 MB heap and all paks held in memory. May need a
  larger heap or memory growth.
- **Emscripten drift.** Upstream only tests emsdk 3.1.58; socket behaviour
  differs between versions. Pin, and re-test on every bump.
- **First-load size** until on-demand downloads return (phase 6).

## Before the first push to the Gitea remote

`.github/workflows/` is still the GitHub set. `release.yaml` triggers on
`master` only, so it stays idle here; `ci.yaml` runs on every other branch
and needs the DHI registry secrets. Decide whether Actions should run on
this repository, or remove the workflows on the working branch until phase 5.
