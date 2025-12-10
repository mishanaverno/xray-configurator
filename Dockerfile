FROM teddysun/xray:latest
RUN apk add --no-cache bash jq gettext coreutils
COPY templates/ /tmp/xray/templates/
COPY scripts/ /scripts/
RUN chmod +x /scripts/*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]