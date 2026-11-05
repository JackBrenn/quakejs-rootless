# All base images are Docker Hardened Images: log in to dhi.io before building.

# Node.js and the game server's npm dependency. This stage also gathers the
# files the server and nginx read, with write access for group and others
# removed whatever the build host's umask.
FROM dhi.io/node:24-debian13-dev@sha256:8c10f88dd9695f3280206c6cb225f4eddcb1211802cceb0fb1fdce1e011fd8cb AS node

WORKDIR /quakejs
COPY quakejs/package.json quakejs/package-lock.json ./
RUN npm ci --omit=dev
COPY quakejs/build/ioq3ded.js build/
COPY server.cfg base/baseq3/server.cfg
COPY server.cfg base/cpma/server.cfg
COPY quakejs/html/ /srv/www/
COPY include/assets/ /srv/www/assets/
RUN chmod -R go-w /quakejs /srv/www

# nginx-light. The base image lacks the adm and www-data accounts and the
# update-rc.d tool that the nginx packages' install scripts expect.
FROM dhi.io/debian-base@sha256:09943fbda2242d48da7d9ebe54a2112f43c37231bfc3e742daafee1846dee8f9 AS nginx

ARG DEBIAN_FRONTEND=noninteractive
RUN echo 'adm:x:4:' >> /etc/group && \
    echo 'www-data:x:33:' >> /etc/group && \
    echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin' >> /etc/passwd && \
    apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confnew" && \
    apt-get install -y --no-install-recommends init-system-helpers nginx-light && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM dhi.io/debian-base@sha256:51579566517b831c425e67462ea8f8c5d7cc8deca960f81a6584a38e0a8d9c11

COPY --from=node /usr/bin/node /usr/bin/node
COPY --from=node /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0 /usr/lib/x86_64-linux-gnu/libcrypt.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=nginx /etc/nginx/mime.types /etc/nginx/mime.types

# Everything is owned by root and read-only to the server user, except the
# game data directory, which the game server fills at startup.
COPY --chmod=644 nginx.conf /etc/nginx/nginx.conf
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY --chmod=644 COPYING LICENSE.MIT /usr/share/doc/quakejs-rootless/
COPY --from=node /srv/www /srv/www
COPY --from=node /quakejs/build /quakejs/build
COPY --from=node /quakejs/node_modules /quakejs/node_modules
COPY --from=node --chown=65532:65532 /quakejs/base /quakejs/base

LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8080/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

USER 65532:65532

ENTRYPOINT ["/entrypoint.sh"]
