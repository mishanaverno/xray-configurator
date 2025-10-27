# Dockerfile for xray based alpine
# Copyright (C) 2019 - 2021 MNaverno <mishanaverno@gmail.com>
# Reference URL:
# https://github.com/XTLS/Xray-core


FROM alpine:latest
LABEL maintainer="MNaverno <mishanaverno@gmail.com>"

WORKDIR /root
VOLUME /etc/xray

COPY config_template.json /etc/xray/config_template.json
COPY .env /root/.env
RUN set -ex \
    && apk update \
    && apk add --no-cache openssl curl tzdata ca-certificates nodejs npm\
    && mkdir -p /var/log/xray /usr/share/xray

COPY install.sh /root/install.sh
RUN chmod +x /root/install.sh
RUN /root/install.sh \
    && rm -f /root/install.sh 
COPY update_geodat.sh /root/update_geodat.sh
RUN chmod +x /root/update_geodat.sh
COPY config.sh /root/config.sh
RUN chmod +x /root/config.sh
COPY entry.sh /root/entry.sh
RUN chmod +x /root/entry.sh
COPY start_web.sh /root/start_web.sh
RUN chmod +x /root/start_web.sh


COPY src /var/opt/subscribe
ENTRYPOINT [ "/root/entry.sh" ]
