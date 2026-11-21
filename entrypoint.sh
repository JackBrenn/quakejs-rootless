#!/bin/bash
# Runs nginx (web client, game data and WebSocket proxy on port 8080), the
# WebSocket-to-UDP bridge and the game server side by side. If any of them
# exits, the container exits with it.
set -euo pipefail

# Until the servers run, a stop request simply ends this script. Without a
# handler the signal would be dropped, as this is the container's first process.
trap 'exit 143' TERM INT

# Until v3 this selected the CPMA mod, which does not run on unmodified ioquake3.
[ "${FS_GAME:-baseq3}" = baseq3 ] || { echo "FS_GAME is no longer supported: remove it" >&2; exit 1; }

# Gather all game data in one directory tree, as the web client does: links to
# the paks in the image, and the paks out of id's installers, which the image
# carries intact. The server also keeps its own files here.
cd /quakejs/base
cp -rsf /srv/www/assets/*/ .
tail -n +165 /srv/www/assets/linuxq3ademo-1.11-6.x86.gz.sh |
    tar -xzf - --warning=no-alone-zero-block demoq3/pak0.pk3
tail -n +356 /srv/www/assets/linuxq3apoint-1.32b-3.x86.run | tar -xzf - --wildcards 'baseq3/pak?.pk3'

# The server looks for its settings among the game data: the image's
# server.cfg, or one mounted over it.
ln -sf /etc/quakejs/server.cfg baseq3/

trap 'kill -TERM $(jobs -p) 2>/dev/null || true' TERM INT

nginx -g 'daemon off;' &
node /quakejs/bridge.js &
# The demo's pak0.pk3 is only accepted from a demoq3 directory (fs_basegame).
# The game's log goes to standard output already, so it needs no log file.
ioq3ded +set dedicated 1 +set net_ip 127.0.0.1 +set g_log '""' \
    +set fs_basepath /quakejs/base +set fs_homepath /quakejs/base \
    +set fs_basegame demoq3 +exec server.cfg &

status=0
wait -n || status=$?
# shellcheck disable=SC2046 # one argument per job PID is intended
kill -TERM $(jobs -p) 2>/dev/null || true
wait || true
exit "$status"
