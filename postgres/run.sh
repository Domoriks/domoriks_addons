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

sanitize_listen_addresses() {
  local raw="$1"
  local addr=""

  # Keep value predictable for postgres -c parsing.
  raw="${raw// /}"

  if [ -z "${raw}" ]; then
    echo "*"
    return
  fi

  if [ "${raw}" = "*" ]; then
    echo "*"
    return
  fi

  IFS=',' read -r -a parts <<< "${raw}"
  for addr in "${parts[@]}"; do
    if [ -z "${addr}" ]; then
      echo "*"
      return
    fi

    if [ "${addr}" = "localhost" ]; then
      continue
    fi

    if [[ "${addr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      continue
    fi

    if [[ "${addr}" =~ ^[0-9a-fA-F:]+$ ]]; then
      continue
    fi

    echo "[warning] Invalid listen_addresses value '${raw}'. Falling back to '*'" >&2
    echo "*"
    return
  done

  echo "${raw}"
}

LISTEN_ADDRESSES="$(sanitize_listen_addresses "${LISTEN_ADDRESSES}")"

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
