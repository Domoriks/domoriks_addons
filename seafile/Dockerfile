# Official Seafile CE image — includes Seafile, Seahub, Nginx and all Python deps.
# We add MariaDB + Redis (bundled local services) and layer s6-overlay + Bashio
# so Home Assistant Supervisor can manage the add-on lifecycle.
ARG BUILD_FROM=seafileltd/seafile-mc:13.0-latest
FROM ${BUILD_FROM}

ARG BASHIO_REPOSITORY=hassio-addons/bashio
ARG BASHIO_VERSION=0.17.5
ARG S6_OVERLAY_REPOSITORY=just-containers/s6-overlay
ARG S6_OVERLAY_VERSION=3.2.2.0
ARG TARGETARCH

ENV \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    SEAFILE_LOG_TO_STDOUT=true

SHELL ["/bin/bash", "-o", "pipefail", "-x", "-c"]

RUN \
    if [ -z "${TARGETARCH}" ]; then \
        echo "TARGETARCH is not set, please build with Docker BuildKit." && exit 1; \
    fi

# ── Bundled MariaDB + Redis (Seafile image expects external DB/cache) ──────
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    redis-server \
    curl \
    jq \
    xz-utils \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ── s6-overlay ─────────────────────────────────────────────────────────────
RUN \
    case "${TARGETARCH}" in \
        amd64) S6_OVERLAY_ARCH="x86_64" ;; \
        arm64) S6_OVERLAY_ARCH="aarch64" ;; \
        *) S6_OVERLAY_ARCH="${TARGETARCH}" ;; \
    esac \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/${S6_OVERLAY_REPOSITORY}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
        | tar Jxvf - -C /

# ── Bashio ─────────────────────────────────────────────────────────────────
RUN \
    mkdir -p /usr/src/bashio \
    && curl -L -f -s "https://github.com/${BASHIO_REPOSITORY}/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar xzf - -C /usr/src/bashio --strip-components=1 \
    && mv /usr/src/bashio/lib /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && mkdir -p /etc/fix-attrs.d /etc/services.d \
    && rm -rf /usr/src/bashio

COPY rootfs/ /
RUN chmod +x \
    /etc/cont-init.d/seafile.sh \
    /etc/services.d/mariadb/run \
    /etc/services.d/mariadb/finish \
    /etc/services.d/redis/run \
    /etc/services.d/redis/finish \
    /etc/services.d/seafile/run \
    /etc/services.d/seafile/finish \
    /scripts/start.sh

VOLUME ["/share/seafile"]

ENV \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_CMD_WAIT_FOR_SERVICES=1 \
    S6_SERVICES_READYTIME=50

ENTRYPOINT ["/init"]
