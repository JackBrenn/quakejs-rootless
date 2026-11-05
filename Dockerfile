# All base images are Docker Hardened Images: log in to dhi.io before building.

# Node.js and the game server's npm dependencies
FROM dhi.io/node:22-debian13-dev@sha256:a76783c3f0e74ffffa624d3849268d2319cc6feacacb8f16c03fa6b6acde1e17 AS node

COPY ./quakejs /quakejs
WORKDIR /quakejs
RUN npm ci --omit=dev

# Make the browser engine's hardcoded URLs scheme-aware so that clients
# served over TLS fetch assets and connect using the page's own protocol,
# instead of relying on the CSP upgrade-insecure-requests header surviving
# the whole reverse-proxy chain. The grep assertions fail the build if the
# rewrite is incomplete. See the provenance header in html/ioquake3.js and
# README 'Modifications to GPL-covered files'.
RUN sed -i \
        -e "s|'http://' + root|'//' + root|g" \
        -e "s|'http://' + fs_cdn|'//' + fs_cdn|g" \
        -e "s|'ws://' + addr|((typeof location!=='undefined'\&\&location.protocol==='https:')?'wss://':'ws://') + addr|g" \
        html/ioquake3.js \
    && ! grep -q "'http://'" html/ioquake3.js \
    && ! grep -q "'ws://' + addr" html/ioquake3.js \
    && grep -q "typeof location!=='undefined'" html/ioquake3.js

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

COPY --from=node --chown=65532:65532 /quakejs /quakejs

RUN mkdir -p /home/nonroot/www && \
    chown -R 65532:65532 /home/nonroot/www /quakejs

COPY --chown=65532:65532 server.cfg /quakejs/base/baseq3/server.cfg
COPY --chown=65532:65532 server.cfg /quakejs/base/cpma/server.cfg

RUN cp /quakejs/html/* /home/nonroot/www/ && \
    chown -R 65532:65532 /home/nonroot/www

COPY --chown=65532:65532 ./include/assets/ /home/nonroot/www/assets
COPY --chown=65532:65532 nginx.conf /etc/nginx/nginx.conf

COPY --chown=65532:65532 --chmod=755 entrypoint.sh /entrypoint.sh
COPY --chown=65532:65532 COPYING LICENSE.MIT README.md /usr/share/doc/quakejs-rootless/
LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8080/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

USER nonroot

ENTRYPOINT ["/entrypoint.sh"]
