#!/bin/bash
set -e

SEAFILE_SH=""
SEAHUB_SH=""

cleanup() {
    echo "[INFO] Stopping Seafile application..."
    if [ -n "${SEAHUB_SH}" ]; then
        "${SEAHUB_SH}" stop >/dev/null 2>&1 || true
    fi
    if [ -n "${SEAFILE_SH}" ]; then
        "${SEAFILE_SH}" stop >/dev/null 2>&1 || true
    fi
}

trap cleanup TERM INT

# Wait for MariaDB to be ready and test connection
echo "[INFO] Waiting for MariaDB to accept connections..."
for i in {1..30}; do
    if mysqladmin ping -h127.0.0.1 --silent >/dev/null 2>&1; then
        echo "[OK] MariaDB is ready and accepting connections"
        echo "[DB] MariaDB listening on 127.0.0.1:3306"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] MariaDB failed to become ready after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Wait for Redis to be ready and test connection
echo "[INFO] Waiting for Redis to accept connections..."
for i in {1..30}; do
    if redis-cli -h 127.0.0.1 -p 6379 ping >/dev/null 2>&1; then
        echo "[OK] Redis is ready and accepting connections"
        echo "[REDIS] Redis listening on 127.0.0.1:6379"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] Redis failed to become ready after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Avoid nested init systems under supervisord; start app services directly.
echo "[INFO] Starting Seafile application..."
echo "=========================================="
echo "[SEAFILE] Seafile application starting up"
echo "[SEAFILE] Database: MariaDB @ 127.0.0.1:3306"
echo "[SEAFILE] Cache: Redis @ 127.0.0.1:6379"
echo "[SEAFILE] Web server: http://127.0.0.1:8000"
echo "=========================================="

if [ -x /etc/my_init.d/01_create_data_links.sh ]; then
    /etc/my_init.d/01_create_data_links.sh
fi

SEAFILE_SH="$(find /opt/seafile -maxdepth 3 -type f -name seafile.sh | head -n 1)"
SEAHUB_SH="$(find /opt/seafile -maxdepth 3 -type f -name seahub.sh | head -n 1)"

if [ -z "${SEAFILE_SH}" ] || [ -z "${SEAHUB_SH}" ]; then
    echo "[ERROR] Could not locate Seafile startup scripts under /opt/seafile"
    exit 1
fi

chmod +x "${SEAFILE_SH}" "${SEAHUB_SH}" >/dev/null 2>&1 || true

"${SEAFILE_SH}" start
"${SEAHUB_SH}" start-fastcgi

exec nginx -g 'daemon off;'
