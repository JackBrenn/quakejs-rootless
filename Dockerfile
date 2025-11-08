FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Combine RUN commands to reduce layers and clean up in same layer
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        nodejs \
        npm \
        jq \
        procps \
        ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 quakejs

# Create quakejs directory and web root
RUN mkdir -p /quakejs /home/quakejs/www && \
    chown -R quakejs:quakejs /quakejs /home/quakejs

# Clone quakejs as root but set ownership
RUN cd / && \
    #Build from own fork of nerosketch/quakejs.git repository
    #git clone https://github.com/nerosketch/quakejs.git && \
    git clone https://github.com/JackBrenn/quakejs.git && \
    chown -R quakejs:quakejs /quakejs

# Switch to non-root user for npm install
USER quakejs
WORKDIR /quakejs
RUN npm install --only=production

# Switch back to root for file copying
USER root

COPY --chown=quakejs:quakejs server.cfg /quakejs/base/baseq3/server.cfg
COPY --chown=quakejs:quakejs server.cfg /quakejs/base/cpma/server.cfg
COPY --chown=quakejs:quakejs ./include/ioq3ded/ioq3ded.fixed.js /quakejs/build/ioq3ded.js

# Copy web files to user directory
RUN cp /quakejs/html/* /home/quakejs/www/ && \
    chown -R quakejs:quakejs /home/quakejs/www

COPY --chown=quakejs:quakejs ./include/assets/ /home/quakejs/www/assets

# Install nginx
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx-light && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=quakejs:quakejs nginx.conf /etc/nginx/nginx.conf

# Create nginx temp directories
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R quakejs:quakejs /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

COPY --chown=quakejs:quakejs --chmod=755 entrypoint.sh /entrypoint.sh

EXPOSE 8080 27960

USER quakejs

ENTRYPOINT ["/entrypoint.sh"]
