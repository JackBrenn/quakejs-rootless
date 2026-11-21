#!/usr/bin/env bash
# Smoke test: build the image, run it, and check that it serves the game.
# Usage: [ENGINE=docker] test/smoke.sh [image]   (an image skips the build)
set -euo pipefail
cd "$(dirname "$0")/.."

engine=${ENGINE:-$(command -v podman || command -v docker)}
image=${1:-quakejs-rootless:smoke}
port=${PORT:-18080}
name=quakejs-smoke-$$
url=http://127.0.0.1:$port

[ -n "${1:-}" ] || "$engine" build -t "$image" .
trap '"$engine" rm -f "$name" >/dev/null 2>&1' EXIT
"$engine" run -d --name "$name" -p "127.0.0.1:$port:8080" "$image" >/dev/null

fail() { "$engine" logs "$name" 2>&1 | tail -n 30; echo "FAIL: $*" >&2; exit 1; }

# The game server is ready once it has loaded the first map.
for i in $(seq 90); do
  "$engine" logs "$name" 2>&1 | grep -q 'AAS initialized' && break
  [ "$i" = 90 ] && fail "game server did not start"
  sleep 2
done

curl -fsS "$url/" | grep -q main.js || fail "index page"
curl -fsSI "$url/" | grep -qi '^x-content-type-options: nosniff' || fail "security headers"
curl -fsSI "$url/ioquake3.wasm" | grep -qi '^content-type: application/wasm' || fail "engine not served as WebAssembly"
curl -fsS "$url/assets/baseq3/" | grep -q pak100.pk3 || fail "game data listing"
# Ask the game server for its status through nginx's WebSocket proxy, as a client would.
"$engine" exec -w /quakejs "$name" node -e '
  const ws = new (require("ws"))("ws://127.0.0.1:8080/");
  setTimeout(() => process.exit(1), 5000);
  ws.on("open", () => ws.send(Buffer.from("\xff\xff\xff\xffgetstatus\n", "latin1")));
  ws.on("message", (d) => d.includes("statusResponse") && process.exit(0));
' || fail "game server did not answer over WebSocket"

"$engine" exec "$name" touch /srv/www/index.html 2>/dev/null && fail "the web root is writable"

start=$SECONDS
"$engine" stop -t 10 "$name" >/dev/null 2>&1
(( SECONDS - start < 5 )) || fail "container took $((SECONDS - start))s to stop"

echo PASS
