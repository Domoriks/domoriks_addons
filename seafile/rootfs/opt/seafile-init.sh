#!/bin/bash
# Runs as the foreground argument to my_init.
# By the time this executes, runit has already booted and is supervising
# nginx, mariadb, and redis via /etc/service/*/run scripts.

echo ""
echo "=========================================="
echo "  Seafile DB Initialization"
echo "=========================================="
echo ""

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
mysql -u root --socket=/var/run/mysqld/mysqld.sock 2>&1 <<'EOSQL'
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS ccnet_db   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS seafile_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS seahub_db  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'seafile'@'127.0.0.1' IDENTIFIED BY '';
CREATE USER IF NOT EXISTS 'seafile'@'localhost'  IDENTIFIED BY '';
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
if [ ! -f "${ENV_FILE}" ]; then
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
DB_ROOT_PASSWD=${DB_ROOT_PASSWD:-}
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
EOF
    echo "[OK] .env written."
else
    echo "[INFO] ${ENV_FILE} already exists, skipping."
fi

# ---- Hand off to Seafile's native entrypoint --------------------------
echo ""
echo "=========================================="
echo "  Starting Seafile (enterpoint.sh)"
echo "=========================================="
echo ""
exec /scripts/enterpoint.sh
