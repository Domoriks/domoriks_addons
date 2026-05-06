#!/bin/bash
# Initialize MariaDB users and databases for Seafile
# This script runs after runit services start (including MariaDB)
# and before the foreground process (enterpoint.sh) runs.

set -e

echo ""
echo "=========================================="
echo "  INIT: MariaDB and Redis Setup"
echo "=========================================="
echo ""

echo "[INFO] Waiting for MariaDB to accept connections..."
for i in {1..30}; do
    if mysqladmin ping -u root -h 127.0.0.1 -p"${DB_ROOT_PASSWD}" 2>/dev/null; then
        echo "[SUCCESS] MariaDB is ready (attempt $i/30)."
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] MariaDB failed to become ready after 30 seconds"
        echo "[DEBUG] Checking MariaDB process:"
        ps aux | grep -i mysql || true
        echo "[DEBUG] Checking /var/run/mysqld:"
        ls -la /var/run/mysqld 2>/dev/null || echo "  (directory not found)"
        exit 1
    fi
    echo "[WAIT] MariaDB not ready yet (attempt $i/30)..."
    sleep 1
done

echo "[INFO] Waiting for Redis to accept connections..."
for i in {1..30}; do
    if redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null | grep -q PONG; then
        echo "[SUCCESS] Redis is ready (attempt $i/30)."
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] Redis failed to become ready after 30 seconds"
        echo "[DEBUG] Checking Redis process:"
        ps aux | grep -i redis || true
        exit 1
    fi
    echo "[WAIT] Redis not ready yet (attempt $i/30)..."
    sleep 1
done

echo "[INFO] Initializing MariaDB users and databases..."

# Create databases and users before Seafile tries to connect
{
    mysql -u root -h 127.0.0.1 -p"${DB_ROOT_PASSWD}" <<'EOSQL'
-- Grant root full privileges on TCP connection (not just socket)
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;

-- Create Seafile databases with UTF8 collation
CREATE DATABASE IF NOT EXISTS ccnet_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS seafile_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS seahub_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create Seafile user with empty password (matches MariaDB default auth model)
CREATE USER IF NOT EXISTS 'seafile'@'127.0.0.1' IDENTIFIED BY '';
CREATE USER IF NOT EXISTS 'seafile'@'localhost' IDENTIFIED BY '';

-- Grant privileges to Seafile user on all three databases
GRANT ALL PRIVILEGES ON ccnet_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seahub_db.* TO 'seafile'@'127.0.0.1';

GRANT ALL PRIVILEGES ON ccnet_db.* TO 'seafile'@'localhost';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'localhost';
GRANT ALL PRIVILEGES ON seahub_db.* TO 'seafile'@'localhost';

FLUSH PRIVILEGES;
EOSQL
} && echo "[SUCCESS] MariaDB databases and users initialized." || {
    echo "[ERROR] Failed to initialize MariaDB"
    exit 1
}

echo ""
