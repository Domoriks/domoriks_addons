#!/bin/bash
set -e

# Read HA add-on config via environment variables (HA passes these)
EXTERNAL_URL="${external_url:-http://127.0.0.1:8000}"
ADMIN_EMAIL="${admin_email:-admin@example.com}"
ADMIN_PASSWORD="${admin_password:-a_very_secure_password_CHANGEME}"

# Parse hostname from external URL
URL_NO_SCHEME="${EXTERNAL_URL#http://}"
URL_NO_SCHEME="${URL_NO_SCHEME#https://}"
HOST_WITH_PORT="${URL_NO_SCHEME%%/*}"
HOSTNAME_ONLY="${HOST_WITH_PORT%%:*}"

if [ -z "${HOSTNAME_ONLY}" ]; then
    HOSTNAME_ONLY="127.0.0.1"
fi

# Derive SERVICE_URL and FILE_SERVER_ROOT for seahub_settings.py
# SERVICE_URL = the full external URL (what users type in browser / client)
# FILE_SERVER_ROOT = same host but port 8082 (direct fileserver access)
export SERVICE_URL_VALUE="${EXTERNAL_URL}"
export FILE_SERVER_ROOT_VALUE="http://${HOSTNAME_ONLY}:8082"

# ---- Persistence setup ------------------------------------------------
# /data is the only automatically persistent path in HA addons.
# Symlink MariaDB and Seafile data directories to /data so they survive restarts.
PERSISTENT_MYSQL="/data/mysql"
PERSISTENT_SEAFILE="/data/seafile"
mkdir -p "${PERSISTENT_MYSQL}" "${PERSISTENT_SEAFILE}"

# MariaDB: use /data/mysql as datadir via symlink
if [ ! -L /var/lib/mysql ] && [ -d /var/lib/mysql ]; then
    # First run with existing (empty) /var/lib/mysql dir - move any contents
    if [ "$(ls -A /var/lib/mysql 2>/dev/null)" ]; then
        cp -a /var/lib/mysql/. "${PERSISTENT_MYSQL}/" 2>/dev/null || true
    fi
    rm -rf /var/lib/mysql
fi
ln -sfn "${PERSISTENT_MYSQL}" /var/lib/mysql
chown mysql:mysql "${PERSISTENT_MYSQL}" 2>/dev/null || true

# Seafile: use /data/seafile as /shared/seafile via symlink
mkdir -p /shared
if [ ! -L /shared/seafile ] && [ -d /shared/seafile ]; then
    if [ "$(ls -A /shared/seafile 2>/dev/null)" ]; then
        cp -a /shared/seafile/. "${PERSISTENT_SEAFILE}/" 2>/dev/null || true
    fi
    rm -rf /shared/seafile
fi
ln -sfn "${PERSISTENT_SEAFILE}" /shared/seafile

echo "[INFO] Persistence: MariaDB -> ${PERSISTENT_MYSQL}, Seafile -> ${PERSISTENT_SEAFILE}"

# Set environment for Seafile to connect to local services
export DB_HOST="127.0.0.1"
export DB_PORT="3306"
export DB_ROOT_PASSWD=""
export DB_USER="seafile"
export DB_PASSWORD=""
export REDIS_HOST="127.0.0.1"
export REDIS_PORT="6379"
export TIME_ZONE="Etc/UTC"
export SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
export SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"
export SEAFILE_SERVER_HOSTNAME="${HOSTNAME_ONLY}"
export SEAFILE_SERVER_PROTOCOL="http"
export SEAFILE_PUBLISH_PORT="80"   # nginx internal port; HA maps this to 8000 externally
# New env-var API (post-Apr 2025 scripts) — export both old and new names
export SEAFILE_MYSQL_DB_HOST="127.0.0.1"
export SEAFILE_MYSQL_DB_PORT="3306"
export SEAFILE_MYSQL_DB_USER="seafile"
export SEAFILE_MYSQL_DB_PASSWORD=""
export SEAFILE_MYSQL_DB_CCNET_DB_NAME="ccnet_db"
export SEAFILE_MYSQL_DB_SEAFILE_DB_NAME="seafile_db"
export SEAFILE_MYSQL_DB_SEAHUB_DB_NAME="seahub_db"
export INIT_SEAFILE_MYSQL_ROOT_PASSWORD=""
export INIT_SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
export INIT_SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"

echo "[INFO] Seafile add-on starting..."
echo "[INFO] External URL: ${EXTERNAL_URL}"
echo "[INFO] Seafile hostname: ${HOSTNAME_ONLY}"
echo "[INFO] Admin email: ${ADMIN_EMAIL}"
echo "[INFO] SERVICE_URL: ${SERVICE_URL_VALUE}"
echo "[INFO] FILE_SERVER_ROOT: ${FILE_SERVER_ROOT_VALUE}"
echo ""

if [ "${ADMIN_PASSWORD}" = "a_very_secure_password_CHANGEME" ]; then
  echo "[WARNING] Using placeholder admin password. Change CHANGEME value after testing."
fi

# Initialize MariaDB data directory if first run
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[INFO] Initializing MariaDB database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql 2>/dev/null || true
    mkdir -p /var/run/mysqld
    chown mysql:mysql /var/run/mysqld /var/lib/mysql 2>/dev/null || true
fi

# Start my_init (boots runit -> nginx/mariadb/redis services), then exec seafile-init.sh
# seafile-init.sh waits for DB/Redis, creates users, writes .env, then execs enterpoint.sh
exec /sbin/my_init -- /opt/seafile-init.sh
