ARG BUILD_FROM=ghcr.io/immich-app/postgres:14-vectorchord0.5.3
FROM $BUILD_FROM

ARG BASHIO_REPOSITORY=hassio-addons/bashio
ARG BASHIO_VERSION=0.17.5
ARG S6_OVERLAY_ARCH
ARG S6_OVERLAY_REPOSITORY=just-containers/s6-overlay
ARG S6_OVERLAY_VERSION=3.2.2.0
ARG TARGETARCH

ENV \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-x", "-c"]

RUN \
    if [ -z "${TARGETARCH}" ]; then \
        echo "TARGETARCH is not set, please use Docker BuildKit for the build." && exit 1; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    jq \
    curl \
    ca-certificates \
    xz-utils \
    gosu \
    pwgen \
    && rm -rf /var/lib/apt/lists/*

RUN \
    if [ -d /etc/postgresql-common ]; then \
        printf 'create_main_cluster = false\n' > /etc/postgresql-common/createcluster.conf; \
    fi

RUN \
    case "${TARGETARCH}" in \
        amd64) S6_OVERLAY_ARCH="${S6_OVERLAY_ARCH:-x86_64}" ;; \
        arm64) S6_OVERLAY_ARCH="${S6_OVERLAY_ARCH:-aarch64}" ;; \
        *) S6_OVERLAY_ARCH="${S6_OVERLAY_ARCH:-${TARGETARCH}}" ;; \
    esac \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
        | tar Jxvf - -C / \
    && mkdir -p /usr/src/bashio \
    && curl -L -f -s "https://github.com/${BASHIO_REPOSITORY}/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar xzf - -C /usr/src/bashio --strip-components=1 \
    && mv /usr/src/bashio/lib /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && mkdir -p /etc/fix-attrs.d /etc/services.d \
    && rm -rf /usr/src/bashio

COPY rootfs /
RUN chmod +x \
    /etc/cont-init.d/postgres.sh \
    /etc/services.d/postgres/run \
    /etc/services.d/postgres/finish \
    /usr/local/bin/postgres-post-init

WORKDIR /

ENV \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_CMD_WAIT_FOR_SERVICES=1 \
    S6_SERVICES_READYTIME=50

ENTRYPOINT ["/init"]
