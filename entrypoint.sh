#!/bin/bash
# Runs nginx (web client, game data and WebSocket proxy on port 8080), the
# WebSocket-to-UDP bridge and the game server side by side. If any of them
# exits, the container exits with it.
set -euo pipefail

case "${FS_GAME:=baseq3}" in
    baseq3|cpma) ;;
    *) echo "FS_GAME must be baseq3 or cpma, not '$FS_GAME'" >&2; exit 1 ;;
esac

# Gather all game data in one directory tree, as the web client does: links to
# the paks in the image, and the paks out of id's installers, which the image
# carries intact. The server also keeps its own files here.
cd /quakejs/base
cp -rsf /srv/www/assets/*/ .
tail -n +165 /srv/www/assets/linuxq3ademo-1.11-6.x86.gz.sh |
    tar -xzf - --warning=no-alone-zero-block demoq3/pak0.pk3
tail -n +356 /srv/www/assets/linuxq3apoint-1.32b-3.x86.run | tar -xzf - --wildcards 'baseq3/pak?.pk3'

# Copy in server.cfg (the image's, or one mounted over /etc/quakejs/server.cfg)
# unless one is already mounted in the game data directory.
cfg=$FS_GAME/server.cfg
[ -e "$cfg" ] || { mkdir -p "$FS_GAME"; cp /etc/quakejs/server.cfg "$cfg"; }

trap 'kill -TERM $(jobs -p) 2>/dev/null || true' TERM INT

nginx -g 'daemon off;' &
node /quakejs/bridge.js &
# The demo's pak0.pk3 is only accepted from a demoq3 directory (fs_basegame).
ioq3ded +set dedicated 1 +set net_ip 127.0.0.1 \
    +set fs_basepath /quakejs/base +set fs_homepath /quakejs/base \
    +set fs_basegame demoq3 +set fs_game "${FS_GAME#baseq3}" +exec server.cfg &

status=0
wait -n || status=$?
# shellcheck disable=SC2046 # one argument per job PID is intended
kill -TERM $(jobs -p) 2>/dev/null || true
wait || true
exit "$status"
