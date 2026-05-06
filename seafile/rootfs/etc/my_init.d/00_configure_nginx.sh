#!/bin/bash
# Configure nginx to listen on 8000 (Seafile default) instead of 80

set -e

echo "[INFO] Configuring nginx to listen on port 8000..."

# Find nginx config files and replace port 80 with 8000
NGINX_CONF_DIRS="/etc/nginx/sites-enabled /etc/nginx/conf.d"

for dir in ${NGINX_CONF_DIRS}; do
    if [ -d "$dir" ]; then
        for conf in "$dir"/*.conf; do
            if [ -f "$conf" ]; then
                echo "[INFO] Checking $conf..."
                # Replace "listen 80;" with "listen 8000;"
                # But preserve other listen directives (e.g., listen [::]:80)
                if grep -q "^[[:space:]]*listen[[:space:]]*80;" "$conf"; then
                    echo "[PATCH] Updating $conf: listen 80 → listen 8000"
                    sed -i 's/^[[:space:]]*listen[[:space:]]*80;/    listen 8000;/' "$conf"
                fi
            fi
        done
    fi
done

echo "[INFO] Nginx port configuration complete."
echo ""
