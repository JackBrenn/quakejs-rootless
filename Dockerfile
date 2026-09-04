#Builder
#Hardened image
# Must be logged in to dhi.io (Docker Hardened Images)
FROM dhi.io/debian-base@sha256:01f7834569c6434fff476e29fb9627166c0baf17adebab865f44b74d66bba2ac AS builder

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confnew" && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    echo 'adm:x:4:' >> /etc/group && \
    echo 'www-data:x:33:' >> /etc/group && \
    echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin' >> /etc/passwd && \
    curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/setup_22.x && \
    EXPECTED_HASH="3006f2db559850b2ecd25296f918e30bb156f04589b1d92af4c60f7b82005c77b69917d15265bff44b90f3bf6f992062fc305e2c85d0d0efef41edef7360baab" && \
    ACTUAL_HASH=$(sha512sum /tmp/setup_22.x | awk '{print $1}') && \
    if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then \
        echo "ERROR: Hash verification failed for setup_22.x" && \
        echo "  Expected: $EXPECTED_HASH" && \
        echo "  Actual:   $ACTUAL_HASH" && \
        exit 1; \
    fi && \
    bash /tmp/setup_22.x && \
    rm -f /tmp/setup_22.x && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get install -y --no-install-recommends nginx-light && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

#Hardened image
# Must be logged in to dhi.io (Docker Hardened Images)
FROM dhi.io/debian-base@sha256:f4f177aca22c32d82d06f53e1d624fa2e0ad12af6d9829b12b69f621d1a679d5

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Copy required binaries
COPY --from=builder /usr/bin/node /usr/bin/node

# Copy core runtime libraries (Node.js, Nginx, Bash dependencies)
COPY --from=builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6
COPY --from=builder /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1
COPY --from=builder /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0 /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypt.so.1 /usr/lib/x86_64-linux-gnu/libcrypt.so.1

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /var/lib/nginx /var/lib/nginx
COPY --from=builder /usr/share/nginx /usr/share/nginx

COPY --from=builder --chown=65532:65532 /quakejs /quakejs

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
