FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Oslo

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install curl git nodejs npm jq apache2 wget apt-utils -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the non-root user early so we can use it in COPY commands
RUN useradd -m -u 1000 sa_quakejs

# Copy and run the local Node.js setup script
COPY nodejs-lts/setup_22.x /tmp/setup_22.x
RUN bash /tmp/setup_22.x

# Copy files with proper ownership from the start
COPY --chown=sa_quakejs:sa_quakejs quakejs-master/ /quakejs/
WORKDIR /quakejs

RUN npm install
RUN ls

COPY --chown=sa_quakejs:sa_quakejs server.cfg /quakejs/base/baseq3/server.cfg
COPY --chown=sa_quakejs:sa_quakejs server.cfg /quakejs/base/cpma/server.cfg
COPY --chown=sa_quakejs:sa_quakejs ./include/ioq3ded/ioq3ded.fixed.js /quakejs/build/ioq3ded.js

RUN rm /var/www/html/index.html && cp /quakejs/html/* /var/www/html/
COPY --chown=sa_quakejs:sa_quakejs ./include/assets/ /var/www/html/assets
RUN ls /var/www/html

WORKDIR /

# Set ownership for web files
RUN chown -R sa_quakejs:sa_quakejs /var/www/html

ADD --chown=sa_quakejs:sa_quakejs entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

# Configure Apache to run on non-privileged port
# Create necessary Apache directories and set permissions for non-root user
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/:80/:8080/' /etc/apache2/sites-enabled/000-default.conf && \
    mkdir -p /var/run/apache2 /var/lock/apache2 && \
    chown -R sa_quakejs:sa_quakejs /var/log/apache2 /var/run/apache2 /var/lock/apache2 && \
    echo "PidFile /var/run/apache2/apache2.pid" >> /etc/apache2/apache2.conf

# Switch to non-root user
USER sa_quakejs

ENTRYPOINT ["/entrypoint.sh"]