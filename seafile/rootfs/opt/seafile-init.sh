#!/bin/bash
set -e

echo "[INFO] Starting Seafile add-on initialization..."
echo "[INFO] MariaDB, Redis, and app initialization will proceed with runit services."
echo ""

# my_init will:
# 1. Start runit daemon (which supervises nginx, mariadb, redis)
# 2. Run /etc/my_init.d/* scripts in alphabetical order (including 02_init_seafile_db.sh)
# 3. Exec /scripts/enterpoint.sh (waits for nginx, runs start.py, monitors seafile/seahub)
exec /sbin/my_init -- /scripts/enterpoint.sh
