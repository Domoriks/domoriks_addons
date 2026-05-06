ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    redis-server \
    supervisor \
    curl \
    bash \
    coreutils \
    grep \
    sed \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /var/log/mysql /var/run/mysqld /opt && \
    chown mysql:mysql /var/run/mysqld /var/log/mysql

COPY rootfs /

# Create nginx service wrapper to patch config for port 8000
# (can't COPY to /etc/service directly as it exists in base image)
RUN mkdir -p /etc/service/nginx && cat > /etc/service/nginx/run <<'NXSCRIPT'
#!/bin/bash
echo "[nginx] Patching config..." >&2
# Remove existing daemon directives to avoid duplicates
sed -i '/^[[:space:]]*daemon/d' /etc/nginx/nginx.conf 2>/dev/null || true
# Patch port 80 -> 8000 in all configs
find /etc/nginx -name "*.conf" 2>/dev/null | xargs sed -i 's/listen 80;/listen 8000;/g' 2>/dev/null || true
find /etc/nginx -name "*.conf" 2>/dev/null | xargs sed -i 's/listen 80 /listen 8000 /g' 2>/dev/null || true
echo "[nginx] Starting..." >&2
exec /usr/sbin/nginx -g "daemon off;"
NXSCRIPT

RUN chmod a+x /run.sh /opt/seafile-init.sh /etc/service/nginx/run

EXPOSE 8000 8082 3306 6379

CMD ["/run.sh"]
