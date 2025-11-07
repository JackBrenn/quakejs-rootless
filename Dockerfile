FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Oslo

RUN apt-get update
RUN apt-get dist-upgrade -y

RUN apt-get install sudo curl git nodejs npm jq apache2 wget apt-utils -y

COPY ./nodejs-ltc/setup_22.x /tmp/setup_22.x
RUN sudo -E bash /tmp/setup_22.x

COPY ./quakejs-master/ /quakejs
WORKDIR /quakejs
RUN npm install
RUN ls
COPY server.cfg /quakejs/base/baseq3/server.cfg
COPY server.cfg /quakejs/base/cpma/server.cfg

COPY ./include/ioq3ded/ioq3ded.fixed.js /quakejs/build/ioq3ded.js

RUN rm /var/www/html/index.html && cp /quakejs/html/* /var/www/html/
COPY ./include/assets/ /var/www/html/assets
RUN ls /var/www/html

WORKDIR /
ADD entrypoint.sh /entrypoint.sh
RUN chmod 777 ./entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]