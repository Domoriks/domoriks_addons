ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-ubuntu:latest
FROM $BUILD_FROM

# ── Install system dependencies ────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # MariaDB
    mariadb-server \
    # Redis
    redis-server \
    # Nginx
    nginx \
    # Python & pip (Seahub runtime)
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    # Seafile build deps
    libmysqlclient-dev \
    libldap2-dev \
    libsasl2-dev \
    libffi-dev \
    # Utilities
    curl \
    wget \
    jq \
    sudo \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ── Download and install Seafile CE ───────────────────────────────────────
# Pinned to a stable release; override with build arg if needed.
ARG SEAFILE_VERSION=11.0.7

RUN mkdir -p /opt/seafile && \
    wget -q "https://github.com/haiwen/seafile-rpi/releases/download/v${SEAFILE_VERSION}/seafile-server_${SEAFILE_VERSION}_stable_pi.tar.gz" \
        -O /tmp/seafile.tar.gz 2>/dev/null || \
    wget -q "https://download.seadrive.org/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz" \
        -O /tmp/seafile.tar.gz && \
    tar xzf /tmp/seafile.tar.gz -C /opt/seafile --strip-components=1 && \
    rm -f /tmp/seafile.tar.gz

# ── Install Seahub Python requirements ────────────────────────────────────
RUN pip3 install --no-cache-dir --break-system-packages \
    django \
    Pillow \
    mysqlclient \
    python-memcached \
    redis \
    requests \
    six \
    pycryptodome \
    PyJWT \
    future \
    chardet \
    gunicorn || true

# ── Nginx config template ──────────────────────────────────────────────────
COPY rootfs/ /

# ── Copy scripts ──────────────────────────────────────────────────────────
COPY run.sh /run.sh
RUN chmod +x /run.sh

# ── Data dir ──────────────────────────────────────────────────────────────
VOLUME ["/share/seafile"]

CMD [ "/run.sh" ]
