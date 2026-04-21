#!/command/with-contenv bashio
# shellcheck shell=bash

set -euo pipefail

write_env() {
    local name="$1"
    local value="$2"

    printf '%s' "${value}" > "/var/run/s6/container_environment/${name}"
}

sanitize_db_host() {
    local raw="$1"

    raw="${raw// /}"
    if [ -z "${raw}" ] || [ "${raw}" = "*" ] || [[ "${raw}" == *","* ]] || [[ ! "${raw}" =~ ^[A-Za-z0-9._:-]+$ ]]; then
        bashio::log.warning "Invalid db_host '${raw:-<empty>}'. Falling back to 'postgres'."
        echo "postgres"
        return
    fi

    echo "${raw}"
}

UPLOAD_LOCATION="$(bashio::config 'upload_location')"
MODEL_CACHE_LOCATION="$(bashio::config 'model_cache_location')"
TZ_VALUE="$(bashio::config 'tz')"
DB_HOST="$(sanitize_db_host "$(bashio::config 'db_host')")"
DB_PORT="$(bashio::config 'db_port')"
DB_USERNAME="$(bashio::config 'db_username')"
DB_PASSWORD="$(bashio::config 'db_password')"
DB_DATABASE_NAME="$(bashio::config 'db_database_name')"
REDIS_PORT="$(bashio::config 'redis_port')"
REDIS_PASSWORD="$(bashio::config 'redis_password')"
MACHINE_LEARNING_URL="$(bashio::config 'machine_learning_url')"

mkdir -p "${UPLOAD_LOCATION}" "${MODEL_CACHE_LOCATION}" /var/lib/redis
chown -R redis:redis /var/lib/redis

write_env UPLOAD_LOCATION "${UPLOAD_LOCATION}"
write_env DB_HOSTNAME "${DB_HOST}"
write_env DB_PORT "${DB_PORT}"
write_env DB_USERNAME "${DB_USERNAME}"
write_env DB_PASSWORD "${DB_PASSWORD}"
write_env DB_DATABASE_NAME "${DB_DATABASE_NAME}"
write_env REDIS_PORT "${REDIS_PORT}"
write_env REDIS_PASSWORD "${REDIS_PASSWORD}"
write_env REDIS_HOSTNAME "127.0.0.1"
write_env TZ "${TZ_VALUE}"
write_env IMMICH_CONFIG_FILE "/dev/null"

if [ -n "${MACHINE_LEARNING_URL}" ]; then
    write_env IMMICH_MACHINE_LEARNING_URL "${MACHINE_LEARNING_URL}"
fi