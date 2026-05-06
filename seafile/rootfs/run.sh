#!/bin/bash
set -e

# Read HA add-on config defaults.
EXTERNAL_URL="${external_url:-http://127.0.0.1:8000}"
ADMIN_EMAIL="${admin_email:-admin@example.com}"
ADMIN_PASSWORD="${admin_password:-a_very_secure_password_CHANGEME}"

# Home Assistant stores add-on options in /data/options.json.
# Read from there so UI config always wins over defaults.
OPTIONS_FILE="/data/options.json"
if [ -f "${OPTIONS_FILE}" ] && command -v jq >/dev/null 2>&1; then
    OPT_EXTERNAL_URL="$(jq -r '.external_url // empty' "${OPTIONS_FILE}" 2>/dev/null || true)"
    OPT_ADMIN_EMAIL="$(jq -r '.admin_email // empty' "${OPTIONS_FILE}" 2>/dev/null || true)"
    OPT_ADMIN_PASSWORD="$(jq -r '.admin_password // empty' "${OPTIONS_FILE}" 2>/dev/null || true)"

    [ -n "${OPT_EXTERNAL_URL}" ] && EXTERNAL_URL="${OPT_EXTERNAL_URL}"
    [ -n "${OPT_ADMIN_EMAIL}" ] && ADMIN_EMAIL="${OPT_ADMIN_EMAIL}"
    [ -n "${OPT_ADMIN_PASSWORD}" ] && ADMIN_PASSWORD="${OPT_ADMIN_PASSWORD}"
fi

# Debug: log what options.json contains
if [ -f "${OPTIONS_FILE}" ]; then
    echo "[DEBUG] options.json found: $(cat ${OPTIONS_FILE})"
else
    echo "[DEBUG] options.json NOT FOUND at ${OPTIONS_FILE}"
fi

# Normalize external URL so generated links are valid.
if [[ "${EXTERNAL_URL}" != http://* && "${EXTERNAL_URL}" != https://* ]]; then
    EXTERNAL_URL="http://${EXTERNAL_URL}"
fi

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
# FILE_SERVER_ROOT = use SERVICE_URL with /seafhttp path for downloads via nginx proxy
# This allows both web UI downloads and native client sync to work through the same port
export SERVICE_URL_VALUE="${EXTERNAL_URL}"
# Extract protocol from SERVICE_URL (keep scheme, host, port, add /seafhttp path)
export FILE_SERVER_ROOT_VALUE="${SERVICE_URL_VALUE%/}/seafhttp"

# Determine whether this is first initialization.
export IS_INITIALIZED=0
if [ -d /shared/seafile/seafile-data ] || [ -d /data/seafile/seafile-data ]; then
    export IS_INITIALIZED=1
fi

# Upstream setup-seafile-mysql.sh rejects short hostnames (like "gas1c") on first boot.
# Use a setup-safe hostname for bootstrap only; URLs are still patched to external_url later.
BOOTSTRAP_HOSTNAME="${HOSTNAME_ONLY}"
if [ "${IS_INITIALIZED}" -eq 0 ]; then
    if ! echo "${HOSTNAME_ONLY}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^[A-Za-z0-9-]+\.[A-Za-z0-9.-]+$'; then
        BOOTSTRAP_HOSTNAME="127.0.0.1"
        echo "[INFO] Using '${BOOTSTRAP_HOSTNAME}' for bootstrap (upstream requires FQDN/IP); URLs will be patched to '${HOSTNAME_ONLY}' after setup."
    fi
fi

# ---- Persistence setup ------------------------------------------------
# /data is the only automatically persistent path in HA addons.
# Symlink MariaDB and Seafile data directories to /data so they survive restarts.
PERSISTENT_MYSQL="/data/mysql"
PERSISTENT_SEAFILE="/data/seafile"
mkdir -p "${PERSISTENT_MYSQL}" "${PERSISTENT_SEAFILE}"

# MariaDB: use /data/mysql as datadir via symlink
if [ ! -L /var/lib/mysql ]; then
    # Only seed /data/mysql from the image if it's truly the first boot (empty persistent dir)
    if [ ! -d "${PERSISTENT_MYSQL}/mysql" ]; then
        echo "[INFO] First boot: seeding MariaDB data from image"
        cp -a /var/lib/mysql/. "${PERSISTENT_MYSQL}/" 2>/dev/null || true
    fi
    rm -rf /var/lib/mysql
fi
ln -sfn "${PERSISTENT_MYSQL}" /var/lib/mysql
chown mysql:mysql "${PERSISTENT_MYSQL}" 2>/dev/null || true

# Seafile: use /data/seafile as /shared/seafile via symlink
mkdir -p /shared
if [ ! -L /shared/seafile ]; then
    # Only seed if persistent dir is empty
    if [ -d /shared/seafile ] && [ "$(ls -A /shared/seafile 2>/dev/null)" ] && [ ! "$(ls -A "${PERSISTENT_SEAFILE}" 2>/dev/null)" ]; then
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
export SEAFILE_SERVER_HOSTNAME="${BOOTSTRAP_HOSTNAME}"
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

if [ "${IS_INITIALIZED}" -eq 1 ]; then
    # Always pass admin creds - upstream handles "already exists" gracefully.
    # Passing empty values causes "Error happened during creating seafile admin".
    export SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
    export SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"
    export INIT_SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
    export INIT_SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"
else
    export SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
    export SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"
    export INIT_SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
    export INIT_SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"
fi

echo "[INFO] Seafile add-on starting..."
echo "[INFO] External URL: ${EXTERNAL_URL}"
echo "[INFO] Seafile hostname: ${HOSTNAME_ONLY}"
echo "[INFO] Admin email: ${ADMIN_EMAIL}"
echo "[INFO] SERVICE_URL: ${SERVICE_URL_VALUE}"
echo "[INFO] FILE_SERVER_ROOT: ${FILE_SERVER_ROOT_VALUE}"
echo "[INFO] Initialized: ${IS_INITIALIZED}"
echo ""

if [ "${IS_INITIALIZED}" -eq 0 ] && [ "${ADMIN_PASSWORD}" = "a_very_secure_password_CHANGEME" ]; then
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
