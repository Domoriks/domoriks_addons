#!/bin/bash
set -e

# Wait for MariaDB to be ready
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

# Ensure root@127.0.0.1 exists for TCP connections (mysql_install_db only creates root@localhost socket user)
echo "[INFO] Initializing MariaDB users for Seafile..."
mysql -u root --socket=/var/run/mysqld/mysqld.sock -e "
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS ccnet_db DEFAULT CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS seafile_db DEFAULT CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS seahub_db DEFAULT CHARACTER SET utf8;
CREATE USER IF NOT EXISTS 'seafile'@'127.0.0.1' IDENTIFIED BY '';
CREATE USER IF NOT EXISTS 'seafile'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON ccnet_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seahub_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ccnet_db.* TO 'seafile'@'localhost';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'localhost';
GRANT ALL PRIVILEGES ON seahub_db.* TO 'seafile'@'localhost';
FLUSH PRIVILEGES;
" 2>/dev/null || true

# Wait for Redis to be ready
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

echo "[INFO] Starting Seafile application..."
echo "=========================================="
echo "[SEAFILE] Seafile application starting up"
echo "[SEAFILE] Database: MariaDB @ 127.0.0.1:3306"
echo "[SEAFILE] Cache: Redis @ 127.0.0.1:6379"
echo "[SEAFILE] Web server: http://127.0.0.1:8000"
echo "=========================================="

# Use the image's designed startup: my_init (runit/nginx) + enterpoint.sh → start.py
# start.py handles: DB init, upgrade checks, seafile.sh start, seahub.sh start
exec /sbin/my_init -- /scripts/enterpoint.sh
