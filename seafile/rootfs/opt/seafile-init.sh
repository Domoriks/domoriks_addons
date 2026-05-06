#!/bin/bash
set -e

SEAFILE_SH=""
SEAHUB_SH=""

ensure_env_file() {
    local target="$1"
    local target_dir
    target_dir="$(dirname "${target}")"

    mkdir -p "${target_dir}" >/dev/null 2>&1 || true

    if [ ! -f "${target}" ]; then
        echo "[INFO] Creating missing ${target} from environment..."
        cat > "${target}" <<EOF
#################################
# Docker compose configurations #
#################################
COMPOSE_FILE='seafile-server.yml,caddy.yml,seadoc.yml'
COMPOSE_PATH_SEPARATOR=','

## Images
SEAFILE_IMAGE=seafileltd/seafile-mc:13.0-latest
SEAFILE_DB_IMAGE=mariadb:10.11
SEAFILE_REDIS_IMAGE=redis
SEAFILE_CADDY_IMAGE=lucaslorentz/caddy-docker-proxy:2.12-alpine
SEADOC_IMAGE=seafileltd/sdoc-server:2.0-latest
NOTIFICATION_SERVER_IMAGE=seafileltd/notification-server:13.0-latest
MD_IMAGE=seafileltd/seafile-md-server:13.0-latest

## Persistent Storage
BASIC_STORAGE_PATH=/opt
SEAFILE_VOLUME=\$BASIC_STORAGE_PATH/seafile-data
SEAFILE_MYSQL_VOLUME=\$BASIC_STORAGE_PATH/seafile-mysql/db
SEAFILE_CADDY_VOLUME=\$BASIC_STORAGE_PATH/seafile-caddy
SEADOC_VOLUME=\$BASIC_STORAGE_PATH/seadoc-data

#################################
#      Startup parameters       #
#################################
SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME:-127.0.0.1}
SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL:-http}
TIME_ZONE=${TIME_ZONE:-Etc/UTC}
JWT_PRIVATE_KEY=

#####################################
# Third-party service configuration #
#####################################

## Database
SEAFILE_MYSQL_DB_HOST=${DB_HOST:-127.0.0.1}
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=${DB_ROOT_PASSWD:-a_very_secure_password_CHANGEME}
SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

## Cache
CACHE_PROVIDER=redis

### Redis
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=

### Memcached
MEMCACHED_HOST=memcached
MEMCACHED_PORT=11211

######################################
#        Initial variables           #
# (Only valid in first-time startup) #
######################################

## Database root password, Used to create Seafile users
INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWD:-a_very_secure_password_CHANGEME}

## Seafile admin user
INIT_SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL:-admin@example.com}
INIT_SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD:-a_very_secure_password_CHANGEME}

############################################
# Additional configurations for extensions #
############################################

## SeaDoc service
ENABLE_SEADOC=true

## Notification
ENABLE_NOTIFICATION_SERVER=false
NOTIFICATION_SERVER_URL=

## Seafile AI
ENABLE_SEAFILE_AI=false
ENABLE_FACE_RECOGNITION=false
SEAFILE_AI_LLM_TYPE=openai
SEAFILE_AI_LLM_URL=
SEAFILE_AI_LLM_KEY=
SEAFILE_AI_LLM_MODEL=gpt-4o-mini

## Metadata server
MD_FILE_COUNT_LIMIT=100000
EOF
    fi
}

cleanup() {
    echo "[INFO] Stopping Seafile application..."
    if [ -n "${SEAHUB_SH}" ]; then
        "${SEAHUB_SH}" stop >/dev/null 2>&1 || true
    fi
    if [ -n "${SEAFILE_SH}" ]; then
        "${SEAFILE_SH}" stop >/dev/null 2>&1 || true
    fi
}

trap cleanup TERM INT

# Wait for MariaDB to be ready and test connection
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

# Avoid nested init systems under supervisord; start app services directly.
echo "[INFO] Starting Seafile application..."
echo "=========================================="
echo "[SEAFILE] Seafile application starting up"
echo "[SEAFILE] Database: MariaDB @ 127.0.0.1:3306"
echo "[SEAFILE] Cache: Redis @ 127.0.0.1:6379"
echo "[SEAFILE] Web server: http://127.0.0.1:8000"
echo "=========================================="

if [ -x /etc/my_init.d/01_create_data_links.sh ]; then
    /etc/my_init.d/01_create_data_links.sh
fi

# Upgrade/start scripts require .env near Seafile root. Ensure both common roots exist.
ensure_env_file /opt/seafile/.env
ensure_env_file /shared/seafile/.env

SEAFILE_SH="$(find /opt/seafile -maxdepth 3 -type f -name seafile.sh | head -n 1)"
SEAHUB_SH="$(find /opt/seafile -maxdepth 3 -type f -name seahub.sh | head -n 1)"

if [ -z "${SEAFILE_SH}" ] || [ -z "${SEAHUB_SH}" ]; then
    echo "[ERROR] Could not locate Seafile startup scripts under /opt/seafile"
    exit 1
fi

chmod +x "${SEAFILE_SH}" "${SEAHUB_SH}" >/dev/null 2>&1 || true

"${SEAFILE_SH}" start
"${SEAHUB_SH}" start-fastcgi

exec nginx -g 'daemon off;'
