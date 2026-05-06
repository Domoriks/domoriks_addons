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
export SEAFILE_PUBLISH_PORT="8000"
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

# Seafile 13 startup/upgrade scripts expect a .env file in /opt/seafile.
if [ -d /opt/seafile ] && [ ! -f /opt/seafile/.env ]; then
    echo "[INFO] Creating missing /opt/seafile/.env from add-on config..."
    cat > /opt/seafile/.env <<EOF
TIME_ZONE=${TIME_ZONE}
SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}
SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL}
SEAFILE_PUBLISH_PORT=${SEAFILE_PUBLISH_PORT}
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_ROOT_PASSWD=${DB_ROOT_PASSWD}
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
EOF
fi

# Some upstream scripts also look under /shared/seafile/.env.
if [ -d /shared/seafile ] && [ ! -f /shared/seafile/.env ]; then
    echo "[INFO] Creating missing /shared/seafile/.env from add-on config..."
    cat > /shared/seafile/.env <<EOF
TIME_ZONE=${TIME_ZONE}
SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}
SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL}
SEAFILE_PUBLISH_PORT=${SEAFILE_PUBLISH_PORT}
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_ROOT_PASSWD=${DB_ROOT_PASSWD}
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
EOF
fi

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

# Let seafile-init.sh handle MariaDB/Redis readiness and startup via image's native mechanism
exec /opt/seafile-init.sh
