#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"

if [ ! -f "${OPTIONS_FILE}" ]; then
  echo "[error] Missing options file at ${OPTIONS_FILE}" >&2
  exit 1
fi

read_opt() {
  local key="$1"
  jq -er ".${key}" "${OPTIONS_FILE}"
}

UPLOAD_LOCATION="$(read_opt upload_location)"
MODEL_CACHE_LOCATION="$(read_opt model_cache_location)"
TZ_VALUE="$(read_opt tz)"
DB_HOST="$(read_opt db_host)"
DB_PORT="$(read_opt db_port)"
DB_USERNAME="$(read_opt db_username)"
DB_PASSWORD="$(read_opt db_password)"
DB_DATABASE_NAME="$(read_opt db_database_name)"
REDIS_PORT="$(read_opt redis_port)"
REDIS_PASSWORD="$(jq -er '.redis_password // ""' "${OPTIONS_FILE}")"
MACHINE_LEARNING_URL="$(jq -er '.machine_learning_url // ""' "${OPTIONS_FILE}")"

# db_host must be a single DNS name or IP. Wildcards are valid for server
# listen addresses, but invalid for client DNS lookups.
DB_HOST="${DB_HOST// /}"
if [ -z "${DB_HOST}" ] || [ "${DB_HOST}" = "*" ] || [[ "${DB_HOST}" == *","* ]] || [[ ! "${DB_HOST}" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  echo "[warning] Invalid db_host '${DB_HOST:-<empty>}'. Falling back to 'postgres'." >&2
  DB_HOST="postgres"
fi

mkdir -p "${UPLOAD_LOCATION}" "${MODEL_CACHE_LOCATION}" /var/lib/redis
chown -R redis:redis /var/lib/redis

REDIS_ARGS=(--port "${REDIS_PORT}" --bind 127.0.0.1)
if [ -n "${REDIS_PASSWORD}" ]; then
  REDIS_ARGS+=(--requirepass "${REDIS_PASSWORD}")
fi
redis-server "${REDIS_ARGS[@]}" --daemonize yes

export UPLOAD_LOCATION
export DB_HOSTNAME="${DB_HOST}"
export DB_PORT
export DB_USERNAME
export DB_PASSWORD
export DB_DATABASE_NAME
export REDIS_HOSTNAME="127.0.0.1"
export REDIS_PASSWORD
export TZ="${TZ_VALUE}"
export IMMICH_CONFIG_FILE=/dev/null

if [ -n "${MACHINE_LEARNING_URL}" ]; then
  export IMMICH_MACHINE_LEARNING_URL="${MACHINE_LEARNING_URL}"
fi

exec /bin/bash -c "start.sh"
