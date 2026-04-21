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

DATA_LOCATION="$(read_opt data_location)"
POSTGRES_USER="$(read_opt postgres_user)"
POSTGRES_PASSWORD="$(read_opt postgres_password)"
POSTGRES_DB="$(read_opt postgres_db)"
LISTEN_ADDRESSES="$(read_opt listen_addresses)"

if [ -z "${POSTGRES_PASSWORD}" ]; then
  echo "[error] postgres_password cannot be empty" >&2
  exit 1
fi

mkdir -p "${DATA_LOCATION}"
chown -R postgres:postgres "${DATA_LOCATION}"

export PGDATA="${DATA_LOCATION}"
export POSTGRES_USER
export POSTGRES_PASSWORD
export POSTGRES_DB

exec docker-entrypoint.sh postgres -c "listen_addresses=${LISTEN_ADDRESSES}"
