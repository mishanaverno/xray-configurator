FROM teddysun/xray:latest AS xray
FROM nginx:alpine

RUN apk add --no-cache bash jq gettext coreutils fcgiwrap spawn-fcgi

RUN addgroup -S xray || true \
 && adduser nginx xray || true \
 && mkdir -p /var/run/xray /var/log/xray \
 && chown -R root:xray /var/run/xray /var/log/xray \
 && chmod 2775 /var/run/xray /var/log/xray

COPY --from=xray /usr/bin/xray /usr/bin/xray
COPY templates/ /tmp/xray/templates/
RUN chmod +w / /tmp/xray/templates/
COPY scripts/ /scripts/
RUN chmod +x /scripts/*
COPY entrypoint.sh /entrypoint.sh
COPY nginx.conf /etc/nginx/nginx.conf
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
