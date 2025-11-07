#!/bin/sh

cd /var/www/html

sed -i "s/'quakejs:/window.location.hostname + ':/g" index.html
sed -i "s/':80'/':${HTTP_PORT}'/g" index.html

# Start Apache in the background as non-root user
/usr/sbin/apache2ctl -D FOREGROUND &
APACHE_PID=$!

cd /quakejs

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $APACHE_PID 2>/dev/null
    kill $QUAKE_PID 2>/dev/null
    exit 0
}

# Trap termination signals
trap shutdown SIGTERM SIGINT

# Start the Quake server in the background
node build/ioq3ded.js +set fs_game baseq3 +set dedicated 1 +exec server.cfg &
QUAKE_PID=$!

# Wait for both processes and exit if either dies
while kill -0 $APACHE_PID 2>/dev/null && kill -0 $QUAKE_PID 2>/dev/null; do
    sleep 1
done

echo "One of the services has stopped"
shutdown