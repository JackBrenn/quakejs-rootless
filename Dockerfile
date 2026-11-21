# The dhi.io base images are Docker Hardened Images: log in to dhi.io before building.

# The engine is built from this ioquake3 commit, with the two changes made in
# the web stage below. To update, change the commit and the checksum of its
# source archive together.
ARG IOQ3_COMMIT=52088b9eae247d8e321c8dc1fb49a879652854f9

FROM scratch AS source
ARG IOQ3_COMMIT
ADD --checksum=sha256:865d50e632a4d30366c465da96cfcf9067fe2d2abca6496f51b000197378bf85 \
    https://github.com/ioquake/ioq3/archive/${IOQ3_COMMIT}.tar.gz /ioq3.tar.gz

# The browser client, as WebAssembly, and the game code (QVMs) that client and
# server both run. The QVMs go in a pk3 named to outrank the incompatible ones
# inside the demo's pak0.pk3. Nothing else from this image ships.
FROM docker.io/emscripten/emsdk:7.0.0@sha256:3803e37bf748ddee14d31cf712fcab09ca367fca83bbefeb78ce4c1f284e6f3f AS web

# The two changes to ioquake3, both for Chromium-based browsers. The build
# fails if either no longer applies.
# 1. It compiles its WebGL shaders at medium float precision, which those
#    browsers pass on to the graphics driver. Distant surfaces then flicker
#    through each other, and per-pixel lighting turns surfaces white. High
#    precision is what desktop OpenGL always uses.
# 2. It re-allocates its dynamic vertex and index buffers before every draw.
#    In those browsers some draws then come out missing or garbled for a
#    frame: walls, models and HUD elements flicker.
COPY --from=source /ioq3.tar.gz /tmp/
RUN mkdir /ioq3 && tar -xzf /tmp/ioq3.tar.gz -C /ioq3 --strip-components=1 && \
    cd /ioq3/code/renderergl2 && \
    grep -q 'precision mediump float;' tr_glsl.c && \
    sed -i 's/precision mediump float;/precision highp float;/' tr_glsl.c && \
    [ "$(grep -c 'tess\.vao->.*Size, NULL, GL_DYNAMIC_DRAW' tr_vbo.c)" = 2 ] && \
    sed -i '/tess\.vao->.*Size, NULL, GL_DYNAMIC_DRAW/d' tr_vbo.c && \
    emcmake cmake -S /ioq3 -B /build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build /build -j "$(nproc)" && \
    cd /build/Release/baseq3 && python3 -m zipfile -c /build/vm.pk3 vm/

# nginx-light, and the game server compiled for Linux. The base image lacks the
# adm and www-data accounts and the update-rc.d tool that the nginx packages'
# install scripts expect.
FROM dhi.io/debian-base@sha256:1c764d726e70d878d3fedf739fd20fc4d1706a7f677e53ff4030a0eeb4fd6424 AS native

ARG DEBIAN_FRONTEND=noninteractive
RUN echo 'adm:x:4:' >> /etc/group && \
    echo 'www-data:x:33:' >> /etc/group && \
    echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin' >> /etc/passwd && \
    apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confnew" && \
    apt-get install -y --no-install-recommends init-system-helpers nginx-light gcc libc6-dev cmake make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# The server parses packets from the network, so build it with the usual hardening.
COPY --from=source /ioq3.tar.gz /tmp/
RUN mkdir /ioq3 && tar -xzf /tmp/ioq3.tar.gz -C /ioq3 --strip-components=1 && \
    CFLAGS='-fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE' LDFLAGS='-pie -Wl,-z,relro,-z,now' \
    cmake -S /ioq3 -B /build -DCMAKE_BUILD_TYPE=Release -DBUILD_CLIENT=OFF -DBUILD_RENDERER_GL1=OFF \
        -DBUILD_RENDERER_GL2=OFF -DBUILD_GAME_LIBRARIES=OFF -DBUILD_GAME_QVMS=OFF && \
    cmake --build /build -j "$(nproc)"

# The licence the web client shows comes out of the demo installer itself.
COPY include/assets/linuxq3ademo-1.11-6.x86.gz.sh /tmp/
RUN tail -n +165 /tmp/linuxq3ademo-1.11-6.x86.gz.sh | tar -xzO Help/Q3A_EULA.txt > /eula.txt

# Node.js and the bridge's npm dependency. This stage also gathers the files
# the servers read, with write access for group and others removed whatever
# the build host's umask. (COPY --chmod is not used for these: Docker's
# BuildKit applies its mode to directories it creates.)
FROM dhi.io/node:24-debian13-dev@sha256:c470ac1a36644b3633ddd65118672ecb8ede1767603d5fbeb34b9e0f51f8f7d7 AS node

WORKDIR /quakejs
COPY quakejs/package.json quakejs/package-lock.json ./
RUN npm ci --omit=dev
COPY quakejs/bridge.js ./
COPY quakejs/html/ /srv/www/
COPY include/assets/ /srv/www/assets/
COPY --from=web /build/Release/ioquake3.js /build/Release/ioquake3.wasm /srv/www/
COPY --from=web /build/vm.pk3 /srv/www/assets/demoq3/
COPY --from=native /eula.txt /srv/www/
COPY server.cfg /etc/quakejs/
COPY COPYING LICENSE.MIT /usr/share/doc/quakejs-rootless/
RUN mkdir base && \
    chmod -R go-w /quakejs /srv/www /etc/quakejs /usr/share/doc/quakejs-rootless

FROM dhi.io/debian-base@sha256:c5274bb35ad2972614a2dbfa4d9727c3f3c0605081b88d1fbae560e53cd8a65a

COPY --from=node /usr/bin/node /usr/bin/node
COPY --from=node /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=native /usr/sbin/nginx /usr/sbin/nginx
COPY --from=native /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0 /usr/lib/x86_64-linux-gnu/libcrypt.so.1 /usr/lib/x86_64-linux-gnu/
COPY --from=native /etc/nginx/mime.types /etc/nginx/mime.types
COPY --from=native /build/Release/ioq3ded /usr/bin/ioq3ded

# Everything is owned by root and read-only to the server user, except the
# game data directory, which the entrypoint fills at startup.
COPY --chmod=644 nginx.conf /etc/nginx/nginx.conf
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY --from=node /etc/quakejs /etc/quakejs
COPY --from=node /usr/share/doc/quakejs-rootless /usr/share/doc/quakejs-rootless
COPY --from=node /srv/www /srv/www
COPY --from=node /quakejs/bridge.js /quakejs/bridge.js
COPY --from=node /quakejs/node_modules /quakejs/node_modules
COPY --from=node --chown=65532:65532 /quakejs/base /quakejs/base

LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8080/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

USER 65532:65532

ENTRYPOINT ["/entrypoint.sh"]
