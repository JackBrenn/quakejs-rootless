# Modernisation: QuakeJS engine → current ioquake3

Working document for this repository. Delete it when the work merges back
into quakejs-rootless.

## Status (2026-11-21)

Phases 1 to 6 are done on the `ioq3-modernisation` branch. The image builds
with podman and passes `test/smoke.sh`. Nothing has been pushed.

The two prebuilt QuakeJS engine files are gone. The image build now compiles
[ioquake/ioq3](https://github.com/ioquake/ioq3) at a pinned commit
(`52088b9`, 2026-11-04) with **two small changes** for Chromium-based
browsers (see decision 6):

```
browser ── http(s)/ws(s) :8080 ──> nginx ──┬─ static: page, ioquake3.js/.wasm, game data
                                           └─ WebSocket ──> bridge.js ── UDP 127.0.0.1:27960 ──> ioq3ded (native)
```

| Piece | What it is now |
|---|---|
| Browser client | ioquake3 as WebAssembly (2.3 MB, 0.9 MB gzipped), built with emsdk 7.0.0 |
| Game server | native Linux `ioq3ded` (0.8 MB), built with stack protector, FORTIFY, PIE, full RELRO |
| Game code | QVMs built from the same ioquake3 source, shipped as `demoq3/vm.pk3` |
| Network | `quakejs/bridge.js`, 40 lines: one WebSocket ↔ one UDP socket |
| Web page | `quakejs/html/`: licence screen, download with progress, installer unpacking, engine start |
| Game data | plain file names, found through nginx JSON directory listings; no manifest |

Against `main`: about 430 lines added, 52,100 removed. Image 350 MB (was 368).

## What was verified, and how

All in headless Chromium on the host GPU, against the container running with a
read-only root filesystem:

- A browser joins the native server over WebSocket and plays; two browsers
  and a bot play together; movement works; about 60 fps.
- Pure server (`sv_pure 1`) checks pass.
- The licence screen, download, in-browser unpacking of id's installers.
- A map change to a custom map: the player downloads the map from the game
  server through the engine's own download screen, then joins.
- Window resize, the in-game menu, `quit` (returns to the first screen), a
  forced fatal error (shows the reason), the game server being down (message).
- Player settings survive a reload (stored in the browser's localStorage).
- `helm lint` and `helm template` pass.
- No Content-Security-Policy violations with the tightened policy.

Play-tested by hand in Firefox and Brave on 2026-11-21, on a 240 Hz display;
both changes in decision 6 were confirmed there. Safari is untested.

**Not tested**: a build with Docker/BuildKit (only podman is installed here).

## Decisions taken along the way

1. **Demo licence handling** — as planned: the image ships id's installers
   intact, the server unpacks them at container start, the browser unpacks
   them after the player accepts the EULA. The EULA text shown is extracted
   from the demo installer at build time.
2. **Pinning ioquake3** — commit and archive checksum at the top of the
   Dockerfile.
3. **Game code** — QVMs built from ioquake3 source.
4. **Bridge** — Node with `ws`, as already in the image.
5. **emsdk** — `emscripten/emsdk:7.0.0` pinned by digest, build stage only.
6. **Two changes to ioquake3**, both `sed` lines in the Dockerfile's web
   stage, both found from play-tests in Brave. Firefox shows neither
   problem; Chrome and Brave show both. Both are worth reporting upstream.
   - *Shaders at high float precision.* Upstream compiles its WebGL shaders
     with `precision mediump float`, which Chromium hands to an OpenGL ES
     driver that applies it. Depth loses precision, so distant surfaces
     flicker through each other, and per-pixel lighting draws surfaces
     white.
   - *No buffer re-allocation per draw.* `RB_UpdateTessVao` re-allocates
     ("orphans") the dynamic vertex and index buffers before every draw.
     Under Chromium some draws then come out missing or garbled for one
     frame: walls, models and HUD elements flicker even with a still camera.
7. **Maps on demand** — the page fetches the `pakN` files and the map being
   played; any other map pak is downloaded by the engine from the game server
   when the map changes (`sv_allowDownload 1`, `sv_dlRate 1000` in
   `server.cfg`). Convention: a map pak is named after its map.
8. **CPMA removed** (confirmed 2026-11-21). CPMA 1.48 refuses to start
   without its full official map pack, and needs a player model only the
   retail game has. QuakeJS got past both with two hacks in its engine that
   rewrote CPMA's bytecode as it loaded. Unmodified ioquake3 has no such
   hacks, and keeping CPMA would have meant carrying equivalent engine
   patches. A container started with `FS_GAME` set to anything but `baseq3`
   exits with a message saying to remove it.

## Known limits

- **First load is about 96 MB** (demo installer 49, point release 31, extra
  paks 19), cached by the browser afterwards. The old client fetched about
  the same.
- **A closed tab leaves a ghost player** until the server's timeout (200 s by
  default; `sv_timeout`). The old server behaved the same way.
- **Some point-release maps show missing textures** (for example pro-q3dm6).
  The textures are not in the game data here; the current release looks the
  same.
- **High-DPI displays render at CSS-pixel resolution.** The web build's SDL
  layer sizes the canvas that way.
- **`quit` detection reads the engine's log line.** On the web the engine
  cannot exit its runtime, so the page watches for
  `----- Client Shutdown (...) -----`. If upstream rewords that line, `quit`
  stops returning to the first screen; nothing else breaks.
- Worth reporting upstream: the two rendering problems in decision 6, and
  `quit` not ending the Emscripten runtime.

## Testing notes

- The in-app browser pane has no WebGL. Tests used Playwright's Chromium
  with `--enable-gpu --use-angle=gl`. Software GL (SwiftShader) fails in the
  renderer's shader setup and is no use. Brave runs the same way through
  Playwright's `executablePath`.
- Flicker does not show in single screenshots. Record the page
  (Playwright's `recordVideo`) with a still camera and compare consecutive
  frames.
- `podman run --rm -p 8080:8080 localhost/quakejs-rootless:dev`, then open
  <http://localhost:8080>.

## Left to do: phase 7, merge back

1. Restore `.github/workflows/ci.yaml` (removed here because this repository
   lives on Gitea). `release.yaml` is unchanged and its path filters still
   match.
2. Bring the branch into quakejs-rootless as v3.0.0. Breaking changes for
   the release notes: CPMA mode, `FS_GAME` and the Helm value `quake.fsGame`
   are gone; game data files lost their checksum prefixes and
   `manifest.json`.
3. Branch CI green on Docker, then an authorised push and merge.

## Working rules (carried over from quakejs-rootless)

- Less code is the goal. Prefer deleting to adding; every addition must earn
  its place.
- Work on a branch, test locally, push only when explicitly authorised.
- No contact details or email addresses anywhere in the repository.
