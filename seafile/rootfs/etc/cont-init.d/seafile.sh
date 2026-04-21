#!/command/with-contenv bashio
# shellcheck shell=bash

set -euo pipefail

write_env() {
    local name="$1"
    local value="$2"
    printf '%s' "${value}" > "/var/run/s6/container_environment/${name}"
}

# ── Bind /shared to HA share directory ────────────────────────────────────
mkdir -p /share/seafile
if [ ! -e /shared ]; then
    ln -s /share/seafile /shared
fi

# ── Read HA config options ─────────────────────────────────────────────────
SERVER_HOSTNAME="$(bashio::config 'server_hostname')"
SERVER_PROTOCOL="$(bashio::config 'server_protocol')"
ADMIN_EMAIL="$(bashio::config 'admin_email')"
ADMIN_PASSWORD="$(bashio::config 'admin_password')"
JWT_PRIVATE_KEY="$(bashio::config 'jwt_private_key')"
MYSQL_ROOT_PASSWORD="$(bashio::config 'mysql_root_password')"
MYSQL_HOST="$(bashio::config 'mysql_host')"
MYSQL_PORT="$(bashio::config 'mysql_port')"
MYSQL_USER="$(bashio::config 'mysql_user')"
MYSQL_PASSWORD="$(bashio::config 'mysql_password')"
CCNET_DB="$(bashio::config 'ccnet_db_name')"
SEAFILE_DB="$(bashio::config 'seafile_db_name')"
SEAHUB_DB="$(bashio::config 'seahub_db_name')"
CACHE_PROVIDER="$(bashio::config 'cache_provider')"
REDIS_HOST="$(bashio::config 'redis_host')"
REDIS_PORT="$(bashio::config 'redis_port')"
REDIS_PASSWORD="$(bashio::config 'redis_password')"
TIME_ZONE="$(bashio::config 'time_zone')"
ENABLE_NOTIFICATION="$(bashio::config 'enable_notification_server')"
NOTIFICATION_URL="$(bashio::config 'notification_server_url')"
MD_FILE_LIMIT="$(bashio::config 'md_file_count_limit')"

# ── Auto-generate secrets if blank ────────────────────────────────────────
if [ -z "${JWT_PRIVATE_KEY}" ]; then
    JWT_PRIVATE_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    bashio::log.warning "jwt_private_key not set; auto-generated for this session."
fi

# ── Export as official Seafile env vars ───────────────────────────────────
write_env SEAFILE_SERVER_HOSTNAME        "${SERVER_HOSTNAME}"
write_env SEAFILE_SERVER_PROTOCOL        "${SERVER_PROTOCOL}"
write_env INIT_SEAFILE_ADMIN_EMAIL       "${ADMIN_EMAIL}"
write_env INIT_SEAFILE_ADMIN_PASSWORD    "${ADMIN_PASSWORD}"
write_env JWT_PRIVATE_KEY                "${JWT_PRIVATE_KEY}"
write_env INIT_SEAFILE_MYSQL_ROOT_PASSWORD "${MYSQL_ROOT_PASSWORD}"
write_env SEAFILE_MYSQL_DB_HOST          "${MYSQL_HOST}"
write_env SEAFILE_MYSQL_DB_PORT          "${MYSQL_PORT}"
write_env SEAFILE_MYSQL_DB_USER          "${MYSQL_USER}"
write_env SEAFILE_MYSQL_DB_PASSWORD      "${MYSQL_PASSWORD}"
write_env SEAFILE_MYSQL_DB_CCNET_DB_NAME    "${CCNET_DB}"
write_env SEAFILE_MYSQL_DB_SEAFILE_DB_NAME  "${SEAFILE_DB}"
write_env SEAFILE_MYSQL_DB_SEAHUB_DB_NAME   "${SEAHUB_DB}"
write_env CACHE_PROVIDER                 "${CACHE_PROVIDER}"
write_env REDIS_HOST                     "${REDIS_HOST}"
write_env REDIS_PORT                     "${REDIS_PORT}"
write_env REDIS_PASSWORD                 "${REDIS_PASSWORD}"
write_env TIME_ZONE                      "${TIME_ZONE}"
write_env ENABLE_NOTIFICATION_SERVER     "${ENABLE_NOTIFICATION}"
write_env NOTIFICATION_SERVER_URL        "${NOTIFICATION_URL}"
write_env MD_FILE_COUNT_LIMIT            "${MD_FILE_LIMIT}"
write_env SEAFILE_LOG_TO_STDOUT          "true"
