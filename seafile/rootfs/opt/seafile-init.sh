#!/bin/bash
set -e

# Wait for MariaDB to be ready and test login
echo "[INFO] Waiting for MariaDB to accept connections..."
for i in {1..30}; do
    if mysqladmin ping -h 127.0.0.1 -u root -p'a_very_secure_password_CHANGEME' --silent >/dev/null 2>&1; then
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

# Let the Seafile base image entrypoint handle initialization and startup
echo "[INFO] Starting Seafile application..."
echo "=========================================="
echo "[SEAFILE] Seafile application starting up"
echo "[SEAFILE] Database: MariaDB @ 127.0.0.1:3306"
echo "[SEAFILE] Cache: Redis @ 127.0.0.1:6379"
echo "[SEAFILE] Web server: http://127.0.0.1:8000"
echo "=========================================="

exec /sbin/my_init
