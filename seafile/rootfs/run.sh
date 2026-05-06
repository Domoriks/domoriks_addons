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
export DB_ROOT_PASSWD="a_very_secure_password_CHANGEME"
export DB_PORT="3306"
export REDIS_HOST="127.0.0.1"
export REDIS_PORT="6379"
export TIME_ZONE="Etc/UTC"
export SEAFILE_ADMIN_EMAIL="${ADMIN_EMAIL}"
export SEAFILE_ADMIN_PASSWORD="${ADMIN_PASSWORD}"
export SEAFILE_SERVER_HOSTNAME="${HOSTNAME_ONLY}"
export SEAFILE_SERVER_PROTOCOL="http"
export SEAFILE_PUBLISH_PORT="8000"

echo "[INFO] Seafile add-on starting..."
echo "[INFO] External URL: ${EXTERNAL_URL}"
echo "[INFO] Seafile hostname: ${HOSTNAME_ONLY}"
echo "[INFO] Admin email: ${ADMIN_EMAIL}"

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

echo "[INFO] Starting supervisord to manage Seafile, MariaDB, and Redis..."

# Reconfigure nginx to listen on port 8000 instead of 80
echo "[INFO] Configuring nginx to listen on port 8000..."
find /etc/nginx -type f -name '*.conf' -exec sed -i 's/listen\s\+80;/listen 8000;/g' {} \; 2>/dev/null || true
find /etc/nginx -type f -name '*.conf' -exec sed -i 's/listen\s\+\[::\]:80;/listen [::]:8000;/g' {} \; 2>/dev/null || true

# Start supervisord in foreground (will never return; s6/HA will manage signal handling)
exec /usr/bin/supervisord -c /etc/supervisord.conf
