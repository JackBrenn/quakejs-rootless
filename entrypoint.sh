#!/bin/bash
# Runs nginx (web client, game data and WebSocket proxy on port 8080) and the
# game server side by side. If either exits, the container exits with it.
set -euo pipefail

case "${FS_GAME:=baseq3}" in
    baseq3|cpma) ;;
    *) echo "FS_GAME must be baseq3 or cpma, not '$FS_GAME'" >&2; exit 1 ;;
esac

trap 'kill -TERM $(jobs -p) 2>/dev/null || true' TERM INT

nginx -g 'daemon off;' &

# The game server downloads its game data from nginx when it starts.
until (exec 3<>/dev/tcp/127.0.0.1/8080) 2>/dev/null; do
    kill -0 $! 2>/dev/null || exit 1
    sleep 0.2
done

cd /quakejs
node build/ioq3ded.js +set fs_game "$FS_GAME" +set dedicated 1 \
    +set net_ip 127.0.0.1 +set fs_cdn 127.0.0.1:8080 +exec server.cfg &

status=0
wait -n || status=$?
kill -TERM $(jobs -p) 2>/dev/null || true
wait || true
exit "$status"
