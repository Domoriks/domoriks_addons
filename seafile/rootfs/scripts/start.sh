#!/bin/bash
# Seafile startup script for Home Assistant add-on
# Handles DB setup, configuration, and service startup

set -euo pipefail

SEAFILE_ROOT="${SEAFILE_ROOT:-/opt/seafile}"

echo "[Seafile] Starting with SEAFILE_ROOT=${SEAFILE_ROOT}"

# ── Check if Seafile server is installed ────────────────────────────────────
if [ ! -d "${SEAFILE_ROOT}/seafile-server-latest" ]; then
    echo "[Seafile] Warning: Seafile server not found at ${SEAFILE_ROOT}/seafile-server-latest"
    echo "[Seafile] Checking for installed seafile version..."
    
    # List contents for debugging
    ls -la "${SEAFILE_ROOT}" || echo "SEAFILE_ROOT does not exist"
    
    # Try to find it
    SEAFILE_SERVER=$(find /opt -maxdepth 3 -name 'seafile.sh' -type f 2>/dev/null | head -1 | xargs dirname)
    if [ -z "${SEAFILE_SERVER}" ]; then
        echo "[ERROR] Could not find Seafile installation"
        exit 1
    fi
fi

SEAFILE_SERVER="${SEAFILE_ROOT}/seafile-server-latest"

# ── Start Seafile services ──────────────────────────────────────────────────
echo "[Seafile] Starting Seafile services..."

cd "${SEAFILE_SERVER}"

# Start Seafile ccnet/seafile daemon
echo "[Seafile] Starting seafile service..."
./seafile.sh start

# Wait a moment for seafile to initialize
sleep 2

# Start Seahub (web interface)
echo "[Seafile] Starting seahub service..."
./seahub.sh start

# Keep container running and show logs
echo "[Seafile] Services started successfully"
sleep 5

# Tail Seafile logs to keep container alive and show output
if [ -f "${SEAFILE_ROOT}/logs/seafile.log" ]; then
    tail -f "${SEAFILE_ROOT}/logs/seafile.log"
else
    # Fallback: just keep the process alive
    while true; do sleep 86400; done
fi

