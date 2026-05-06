ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apk add --no-cache docker-cli docker-cli-compose bash coreutils grep sed

COPY rootfs /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
