#!/bin/bash
# Runs as the foreground argument to my_init.
# By the time this executes, runit has already booted and is supervising
# nginx, mariadb, and redis via /etc/service/*/run scripts.

echo ""
echo "=========================================="
echo "  Seafile DB Initialization"
echo "=========================================="
echo ""

# Ensure Seafile DB user has a real password. If none is provided, generate one
# once and persist it under /shared/seafile for subsequent restarts.
DB_PASS_FILE="/shared/seafile/.db_password"
mkdir -p /shared/seafile
if [ -z "${DB_PASSWORD:-}" ]; then
    if [ -f "${DB_PASS_FILE}" ]; then
        DB_PASSWORD="$(cat "${DB_PASS_FILE}")"
    else
        DB_PASSWORD="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
        printf '%s' "${DB_PASSWORD}" > "${DB_PASS_FILE}"
        chmod 600 "${DB_PASS_FILE}" 2>/dev/null || true
    fi
fi
export DB_PASSWORD
export SEAFILE_MYSQL_DB_PASSWORD="${SEAFILE_MYSQL_DB_PASSWORD:-${DB_PASSWORD}}"

# Ensure a persistent JWT private key exists (required by Seafile 13.0+)
JWT_KEY_FILE="/shared/seafile/.jwt_private_key"
if [ -f "${JWT_KEY_FILE}" ]; then
    JWT_PRIVATE_KEY="$(cat "${JWT_KEY_FILE}")"
else
    JWT_PRIVATE_KEY="$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
    printf '%s' "${JWT_PRIVATE_KEY}" > "${JWT_KEY_FILE}"
    chmod 600 "${JWT_KEY_FILE}" 2>/dev/null || true
fi
export JWT_PRIVATE_KEY

# ---- Wait for MariaDB --------------------------------------------------
echo "[INFO] Waiting for MariaDB..."
for i in $(seq 1 60); do
    if mysqladmin ping -u root --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
        echo "[OK] MariaDB is ready (${i}s)"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[ERROR] MariaDB not ready after 60s"
        echo "[DEBUG] mysqld process: $(pgrep -a mysqld 2>/dev/null || echo none)"
        echo "[DEBUG] /var/run/mysqld: $(ls -la /var/run/mysqld 2>/dev/null || echo missing)"
    fi
    sleep 1
done

# ---- Wait for Redis ----------------------------------------------------
echo "[INFO] Waiting for Redis..."
for i in $(seq 1 30); do
    if redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null | grep -q PONG; then
        echo "[OK] Redis is ready (${i}s)"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[ERROR] Redis not ready after 30s"
        echo "[DEBUG] redis process: $(pgrep -a redis 2>/dev/null || echo none)"
    fi
    sleep 1
done

# ---- Create MariaDB users & databases ---------------------------------
echo "[INFO] Initializing MariaDB users and databases..."
mysql -u root --socket=/var/run/mysqld/mysqld.sock 2>&1 <<EOSQL
-- Switch root@localhost from unix_socket to password auth so start.py can connect
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');
-- Grant root@127.0.0.1 for TCP connections (GRANT IDENTIFIED BY removed in MariaDB 10.11)
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
-- Databases
CREATE DATABASE IF NOT EXISTS ccnet_db   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS seafile_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS seahub_db  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- Seafile users
CREATE USER IF NOT EXISTS 'seafile'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'seafile'@'localhost'  IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER 'seafile'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER 'seafile'@'localhost'  IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ccnet_db.*   TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seahub_db.*  TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ccnet_db.*   TO 'seafile'@'localhost';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'localhost';
GRANT ALL PRIVILEGES ON seahub_db.*  TO 'seafile'@'localhost';
FLUSH PRIVILEGES;
EOSQL
if [ $? -eq 0 ]; then
    echo "[OK] MariaDB databases and users initialized."
else
    echo "[WARN] MariaDB init encountered an issue (may already be initialized)."
fi

# ---- Write .env -------------------------------------------------------
# 01_create_data_links.sh already ran and created /shared/seafile symlinks.
ENV_DIR="/shared/seafile"
mkdir -p "${ENV_DIR}"
ENV_FILE="${ENV_DIR}/.env"
echo "[INFO] Writing ${ENV_FILE}..."
cat > "${ENV_FILE}" <<EOF
JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}
TIME_ZONE=${TIME_ZONE:-Etc/UTC}
SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}
SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL:-http}
SEAFILE_PUBLISH_PORT=${SEAFILE_PUBLISH_PORT:-80}
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-seafile}
DB_PASSWORD=${DB_PASSWORD:-}
DB_ROOT_PASSWD=${DB_ROOT_PASSWD:-}
SEAFILE_MYSQL_DB_HOST=${SEAFILE_MYSQL_DB_HOST:-127.0.0.1}
SEAFILE_MYSQL_DB_PORT=${SEAFILE_MYSQL_DB_PORT:-3306}
SEAFILE_MYSQL_DB_USER=${SEAFILE_MYSQL_DB_USER:-seafile}
SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_MYSQL_DB_PASSWORD:-}
SEAFILE_MYSQL_DB_CCNET_DB_NAME=${SEAFILE_MYSQL_DB_CCNET_DB_NAME:-ccnet_db}
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_MYSQL_DB_SEAFILE_DB_NAME:-seafile_db}
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAFILE_MYSQL_DB_SEAHUB_DB_NAME:-seahub_db}
INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${INIT_SEAFILE_MYSQL_ROOT_PASSWORD:-}
CACHE_PROVIDER=redis
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
INIT_SEAFILE_ADMIN_EMAIL=${INIT_SEAFILE_ADMIN_EMAIL:-${SEAFILE_ADMIN_EMAIL}}
INIT_SEAFILE_ADMIN_PASSWORD=${INIT_SEAFILE_ADMIN_PASSWORD:-${SEAFILE_ADMIN_PASSWORD}}
EOF
echo "[OK] .env written."

# Seafile 13.0 expects .env at /opt/seafile/conf/.env (per upgrade manual).
CONF_DIR="/opt/seafile/conf"
mkdir -p "${CONF_DIR}"
ln -sf "${ENV_FILE}" "${CONF_DIR}/.env" 2>/dev/null || cp -f "${ENV_FILE}" "${CONF_DIR}/.env"
ln -sf "${ENV_FILE}" "/opt/seafile/.env" 2>/dev/null || cp -f "${ENV_FILE}" "/opt/seafile/.env"

# If shared conf already exists (second+ run), link there too
if [ -d /shared/seafile/conf ]; then
    ln -sf "${ENV_FILE}" /shared/seafile/conf/.env 2>/dev/null || cp -f "${ENV_FILE}" /shared/seafile/conf/.env
fi

echo "[INFO] .env locations:"
ls -la /shared/seafile/.env /opt/seafile/conf/.env /opt/seafile/.env 2>/dev/null || true

# ---- Pre-flight DB connectivity check ----------------------------------
# Ensure the seafile user can connect to all three databases before upstream init
# This prevents "Got an error reading communication packets" errors during setup
echo "[INFO] Waiting for database connectivity as seafile user..."
for i in $(seq 1 30); do
    RESULT=$(mysql -u seafile -h 127.0.0.1 -p"${DB_PASSWORD}" -e "SELECT 1;" 2>&1 | grep -c "1" || echo "0")
    if [ "${RESULT}" -gt 0 ]; then
        echo "[OK] Database connectivity verified (${i}s)"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[WARN] Database connectivity test failed after 30s, continuing anyway"
    fi
    sleep 1
done

# ---- Pre-start URL fix (synchronous, before Seahub loads config) --------
# Django constance_config in DB overrides seahub_settings.py at runtime.
# We fix both BEFORE enterpoint.sh starts so Seahub never sees wrong values.
# For first boot the file doesn't exist yet; the background watcher handles that.

patch_nginx_ipv6() {
    local RELOADED=0
    for CONF in \
        /shared/nginx/conf/seafile.nginx.conf \
        /etc/nginx/sites-enabled/seafile.conf \
        /etc/nginx/conf.d/seafile.conf; do
        if [ -f "$CONF" ]; then
            if grep -q 'listen 80;' "$CONF" && ! grep -q 'listen \[::\]:80' "$CONF"; then
                sed -i '/listen 80;/a\        listen [::]:80;' "$CONF"
                echo "[nginx-ipv6] Patched $CONF — added listen [::]:80"
                RELOADED=1
            else
                echo "[nginx-ipv6] $CONF already has IPv6 or no listen 80 — skipping"
            fi
        fi
    done
    if [ "$RELOADED" -eq 1 ] && pgrep -x nginx >/dev/null 2>&1; then
        nginx -s reload 2>/dev/null && echo "[nginx-ipv6] nginx reloaded" || echo "[nginx-ipv6] nginx reload failed (ok if not started yet)"
    fi
}

patch_url_config() {
    local srv="$1" fsr="$2"
    # 1) Patch config files (handles restart case where file already exists)
    for CONF in /opt/seafile/conf/seahub_settings.py /shared/seafile/conf/seahub_settings.py; do
        if [ -f "$CONF" ]; then
            sed -i '/^SERVICE_URL *=/d;/^FILE_SERVER_ROOT *=/d;/^CONSTANCE_BACKEND *=/d' "$CONF"
            echo "SERVICE_URL = '${srv}'" >> "$CONF"
            echo "FILE_SERVER_ROOT = '${fsr}'" >> "$CONF"
            echo "[url-fix] Patched $CONF"
        fi
    done
    # 2) Update constance DB using manage.py so values are pickle-encoded correctly.
    #    On first boot the table doesn't exist yet; the background watcher handles that.
    set_constance_via_django "${srv}" "${fsr}"
}

set_constance_via_django() {
    local srv="$1" fsr="$2"
    local MANAGE
    MANAGE="$(find /opt/seafile/seafile-server-latest/seahub -maxdepth 1 -name 'manage.py' 2>/dev/null | head -1)"
    if [ -z "$MANAGE" ]; then
        echo "[url-fix] manage.py not found, skipping constance DB update"
        return
    fi
    python3 "$MANAGE" shell --no-input -c "
import os, sys
try:
    from constance import config
    config.SERVICE_URL = '${srv}'
    config.FILE_SERVER_ROOT = '${fsr}'
    print('[url-fix] constance DB updated: SERVICE_URL=${srv} FILE_SERVER_ROOT=${fsr}')
except Exception as e:
    print('[url-fix] constance DB update failed (first boot - ok):', e)
    sys.exit(0)
" 2>&1 || echo "[url-fix] manage.py shell exited non-zero (first boot - ok)"
}

patch_url_config "${SERVICE_URL_VALUE}" "${FILE_SERVER_ROOT_VALUE}"
patch_nginx_ipv6

# ---- First-boot background watcher ------------------------------------
# On first boot setup-seafile-mysql.py creates seahub_settings.py during startup.
# Watch for it and patch once it appears, then restart Seahub once.
cat > /opt/apply_addon_urls.sh <<'URLEOF'
#!/bin/bash
SRV="$1"; FSR="$2"
echo "[url-watcher] Waiting for seahub_settings.py (first-boot only)..."

# Wait until the file exists AND has a SERVICE_URL entry (= setup finished writing it)
PATCHED_CONFS=""
for i in $(seq 1 300); do
    for CONF in /opt/seafile/conf/seahub_settings.py /shared/seafile/conf/seahub_settings.py; do
        # Only patch each file once (track by path)
        if [ -f "$CONF" ] && grep -q "^SERVICE_URL" "$CONF" 2>/dev/null; then
            if ! echo "${PATCHED_CONFS}" | grep -qF "${CONF}"; then
                echo "[url-watcher] Config appeared at $CONF, patching..."
                sed -i '/^SERVICE_URL *=/d;/^FILE_SERVER_ROOT *=/d;/^CONSTANCE_BACKEND *=/d' "$CONF"
                echo "SERVICE_URL = '${SRV}'" >> "$CONF"
                echo "FILE_SERVER_ROOT = '${FSR}'" >> "$CONF"
                echo "[url-watcher] Patched $CONF"
                PATCHED_CONFS="${PATCHED_CONFS}:${CONF}"
            fi
        fi
    done
    # Once Seahub is running: update constance DB via manage.py, then restart once.
    if pgrep -f "seahub" >/dev/null 2>&1; then
        if [ -n "${PATCHED_CONFS}" ]; then
            sleep 5
            MANAGE="$(find /opt/seafile/seafile-server-latest/seahub -maxdepth 1 -name 'manage.py' 2>/dev/null | head -1)"
            if [ -n "$MANAGE" ]; then
                echo "[url-watcher] Updating constance DB via manage.py..."
                python3 "$MANAGE" shell --no-input -c "
try:
    from constance import config
    config.SERVICE_URL = '${SRV}'
    config.FILE_SERVER_ROOT = '${FSR}'
    print('[url-watcher] constance DB updated')
except Exception as e:
    print('[url-watcher] constance DB update error:', e)
" 2>&1 || true
            fi
            echo "[url-watcher] Restarting Seahub to load corrected URLs..."
            cd /opt/seafile/seafile-server-latest && ./seahub.sh restart 2>&1 | tail -5
        else
            echo "[url-watcher] Seahub up but config not written yet, waiting..."
            sleep 2
            continue
        fi
        # Patch nginx for IPv6 (homeassistant.local mDNS resolves to IPv6)
        for NGINX_CONF in \
            /shared/nginx/conf/seafile.nginx.conf \
            /etc/nginx/sites-enabled/seafile.conf \
            /etc/nginx/conf.d/seafile.conf; do
            if [ -f "$NGINX_CONF" ]; then
                if grep -q 'listen 80;' "$NGINX_CONF" && ! grep -q 'listen \[::\]:80' "$NGINX_CONF"; then
                    sed -i '/listen 80;/a\        listen [::]:80;' "$NGINX_CONF"
                    echo "[url-watcher] nginx-ipv6: patched $NGINX_CONF"
                    pgrep -x nginx >/dev/null 2>&1 && nginx -s reload 2>/dev/null && echo "[url-watcher] nginx reloaded" || true
                fi
            fi
        done
        echo "[url-watcher] Done"
        exit 0
    fi
    sleep 1
done
echo "[url-watcher] Timeout"
URLEOF
chmod +x /opt/apply_addon_urls.sh

# ---- Hand off to Seafile's native entrypoint --------------------------
echo ""
echo "=========================================="
echo "  Starting Seafile (enterpoint.sh)"
echo "=========================================="
echo ""

# On first boot, launch the background watcher before enterpoint creates the config
if [ "${IS_INITIALIZED:-0}" -eq 0 ]; then
    /opt/apply_addon_urls.sh "${SERVICE_URL_VALUE}" "${FILE_SERVER_ROOT_VALUE}" &
fi

# Ensure the generated .env is exported into the upstream startup process.
set -a
. "${ENV_FILE}"
set +a

/scripts/enterpoint.sh
ENTRYPOINT_RC=$?
if [ "${ENTRYPOINT_RC}" -ne 0 ]; then
    echo "[ERROR] /scripts/enterpoint.sh exited with status ${ENTRYPOINT_RC}"
fi
exit "${ENTRYPOINT_RC}"
