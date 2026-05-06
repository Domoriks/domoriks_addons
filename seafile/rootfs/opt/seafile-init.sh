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
TIME_ZONE=${TIME_ZONE:-Etc/UTC}
SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}
SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL:-http}
SEAFILE_PUBLISH_PORT=${SEAFILE_PUBLISH_PORT:-80}
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-seafile}
DB_PASSWORD=${DB_PASSWORD:-}
DB_ROOT_PASSWD=${DB_ROOT_PASSWD:-}
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
SEAFILE_MYSQL_DB_HOST=${SEAFILE_MYSQL_DB_HOST:-127.0.0.1}
SEAFILE_MYSQL_DB_PORT=${SEAFILE_MYSQL_DB_PORT:-3306}
SEAFILE_MYSQL_DB_USER=${SEAFILE_MYSQL_DB_USER:-seafile}
SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_MYSQL_DB_PASSWORD:-}
SEAFILE_MYSQL_DB_CCNET_DB_NAME=${SEAFILE_MYSQL_DB_CCNET_DB_NAME:-ccnet_db}
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_MYSQL_DB_SEAFILE_DB_NAME:-seafile_db}
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAFILE_MYSQL_DB_SEAHUB_DB_NAME:-seahub_db}
INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${INIT_SEAFILE_MYSQL_ROOT_PASSWORD:-}
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

# ---- Hand off to Seafile's native entrypoint --------------------------
echo ""
echo "=========================================="
echo "  Starting Seafile (enterpoint.sh)"
echo "=========================================="
echo ""
exec /scripts/enterpoint.sh
