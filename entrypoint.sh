#!/bin/bash
set -e

cd /home/quakejs/www

sed -i "s/'quakejs:/window.location.hostname + ':/g" index.html
sed -i "s/':80'/':${HTTP_PORT:-8080}'/g" index.html

# Start Python HTTP server on port 8080
echo "Starting web server on port 8080..."
python3 -m http.server 8080 &
WEB_PID=$!

# Check if web server started
sleep 1
if ! kill -0 $WEB_PID 2>/dev/null; then
    echo "ERROR: Web server failed to start!"
    exit 1
fi

echo "Web server started successfully (PID: $WEB_PID)"

cd /quakejs

echo "Starting QuakeJS server..."
node build/ioq3ded.js +set fs_game baseq3 +set dedicated 1 +exec server.cfg
