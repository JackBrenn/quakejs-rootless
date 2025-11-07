FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Oslo

RUN apt-get update
RUN apt-get dist-upgrade -y

RUN apt-get install sudo curl git nodejs npm jq apache2 wget apt-utils -y

RUN sudo -E bash - nodejs-ltc/setup_22.x
#RUN curl -sL https://deb.nodesource.com/setup_22.x | sudo -E bash -
#Most vulnerabilities are from the depreciated NPM Packages
#RUN git clone https://github.com/JackBrenn/quakejs.git
WORKDIR /quakejs-master
RUN npm install
RUN ls
COPY server.cfg /quakejs/base/baseq3/server.cfg
COPY server.cfg /quakejs/base/cpma/server.cfg
# The two following lines are not necessary because we copy assets from include.  Leaving them here for continuity.
# WORKDIR /var/www/html
# RUN bash /var/www/html/get_assets.sh
COPY ./include/ioq3ded/ioq3ded.fixed.js /quakejs/build/ioq3ded.js

RUN rm /var/www/html/index.html && cp /quakejs/html/* /var/www/html/
COPY ./include/assets/ /var/www/html/assets
RUN ls /var/www/html

WORKDIR /
ADD entrypoint.sh /entrypoint.sh
# Was having issues with Linux and Windows compatibility with chmod -x, but this seems to work in both
RUN chmod 777 ./entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]