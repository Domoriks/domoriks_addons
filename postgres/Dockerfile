ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-ubuntu:latest
FROM $BUILD_FROM

ENV LANG=C.UTF-8

RUN printf 'create_main_cluster = false\n' > /etc/postgresql-common/createcluster.conf \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        gosu \
        postgresql \
        postgresql-client \
        pwgen \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /
RUN chmod +x \
    /etc/cont-init.d/postgres.sh \
    /etc/services.d/postgres/run \
    /etc/services.d/postgres/finish \
    /usr/local/bin/postgres-post-init

WORKDIR /
ENTRYPOINT ["/init"]
