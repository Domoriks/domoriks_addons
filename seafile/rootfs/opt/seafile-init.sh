#!/bin/bash
set -e

# Wait for MariaDB to be ready
echo "[INFO] Waiting for MariaDB to accept connections..."
for i in {1..30}; do
    if mysqladmin ping -h127.0.0.1 --silent >/dev/null 2>&1; then
        echo "[INFO] MariaDB is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] MariaDB failed to become ready"
        exit 1
    fi
    sleep 1
done

# Wait for Redis to be ready
echo "[INFO] Waiting for Redis to accept connections..."
for i in {1..30}; do
    if redis-cli -h 127.0.0.1 ping >/dev/null 2>&1; then
        echo "[INFO] Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] Redis failed to become ready"
        exit 1
    fi
    sleep 1
done

# Let the Seafile base image entrypoint handle initialization and startup
echo "[INFO] Starting Seafile services..."
exec /sbin/my_init
