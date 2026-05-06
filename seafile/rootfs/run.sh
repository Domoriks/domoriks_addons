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

# Set environment for Seafile to connect to local services
export DB_HOST="127.0.0.1"
export DB_PORT="3306"
export DB_ROOT_PASSWD=""
export DB_USER="seafile"
export DB_PASSWORD="${ADMIN_PASSWORD}"
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
export SEAFILE_MYSQL_DB_PASSWORD="${ADMIN_PASSWORD}"
export INIT_SEAFILE_MYSQL_ROOT_PASSWORD=""
export INIT_SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
export INIT_SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"

echo "[INFO] Seafile add-on starting..."
echo "[INFO] External URL: ${EXTERNAL_URL}"
echo "[INFO] Seafile hostname: ${HOSTNAME_ONLY}"
echo "[INFO] Admin email: ${ADMIN_EMAIL}"
echo "[INFO] Exporting environment variables for Seafile..."
echo "  DB_HOST=${DB_HOST}"
echo "  DB_USER=${DB_USER}"
echo "  REDIS_HOST=${REDIS_HOST}"
echo "  SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}"
echo "  SEAFILE_PUBLISH_PORT=${SEAFILE_PUBLISH_PORT}"
echo ""

# NOTE: .env is written by /opt/seafile-db-init-and-start.sh AFTER my_init has
# created the /shared/seafile symlink tree (via 01_create_data_links.sh).
# Do NOT write it here — it would be at the wrong path or get overwritten.

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
