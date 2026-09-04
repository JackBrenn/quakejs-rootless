#!/bin/bash
set -e

# Create nginx temp directories at runtime
mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

cd /home/nonroot/www

# Start Nginx web server
echo "Starting web server on port 8080..."
nginx -c /etc/nginx/nginx.conf

# Wait until nginx actually accepts connections (more reliable than a
# fixed sleep plus a pidfile check)
for i in $(seq 1 30); do
    if node -e "require('net').connect(8080,'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))"; then
        break
    fi
    if [ "$i" = 30 ]; then
        echo "ERROR: web server failed to start"
        exit 1
    fi
    sleep 0.5
done

cd /quakejs

echo "Starting QuakeJS server..."
exec node build/ioq3ded.js +set fs_game "${FS_GAME:-baseq3}" +set dedicated 1 +set fs_cdn "${FS_CDN:-localhost:8080}" +exec "${SERVER_CONFIG:-server.cfg}"
