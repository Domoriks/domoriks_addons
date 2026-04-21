#!/command/with-contenv bashio
# shellcheck shell=bash

set -euo pipefail

write_env() {
    local name="$1"
    local value="$2"

    printf '%s' "${value}" > "/var/run/s6/container_environment/${name}"
}

sanitize_listen_addresses() {
    local raw="$1"
    local addr=""

    raw="${raw// /}"

    if [ -z "${raw}" ] || [ "${raw}" = "*" ]; then
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

        bashio::log.warning "Invalid listen_addresses value '${raw}'. Falling back to '*'."
        echo "*"
        return
    done

    echo "${raw}"
}

require_identifier() {
    local field_name="$1"
    local value="$2"

    if [[ ! "${value}" =~ ^[A-Za-z0-9_-]+$ ]]; then
        bashio::exit.nok "${field_name} may only contain letters, numbers, underscores, and hyphens."
    fi
}

DATA_LOCATION="$(bashio::config 'data_location')"
POSTGRES_USER="$(bashio::config 'postgres_user')"
POSTGRES_PASSWORD="$(bashio::config 'postgres_password')"
POSTGRES_DB="$(bashio::config 'postgres_db')"
LISTEN_ADDRESSES="$(sanitize_listen_addresses "$(bashio::config 'listen_addresses')")"
POSTGRES_BIN_PARENT="$(find /usr/lib/postgresql -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
POSTGRES_BIN_DIR="${POSTGRES_BIN_PARENT}/bin"
NEW_INSTALL="false"

if [ -z "${POSTGRES_PASSWORD}" ]; then
    bashio::exit.nok "postgres_password cannot be empty."
fi

require_identifier "postgres_user" "${POSTGRES_USER}"
require_identifier "postgres_db" "${POSTGRES_DB}"

if [ -z "${POSTGRES_BIN_PARENT}" ] || [ ! -x "${POSTGRES_BIN_DIR}/postgres" ]; then
    bashio::exit.nok "PostgreSQL binaries were not found after package installation."
fi

if [ ! -f "${DATA_LOCATION}/PG_VERSION" ]; then
    NEW_INSTALL="true"
fi

mkdir -p "${DATA_LOCATION}" /var/run/postgresql
chmod 700 "${DATA_LOCATION}"
chmod 775 /var/run/postgresql
chown -R postgres:postgres "${DATA_LOCATION}" /var/run/postgresql

if bashio::var.true "${NEW_INSTALL}"; then
    bashio::log.info "Initializing PostgreSQL data directory..."
    gosu postgres "${POSTGRES_BIN_DIR}/initdb" \
    --username="${POSTGRES_USER}" \
        --auth-local=trust \
        --auth-host=scram-sha-256 \
        -D "${DATA_LOCATION}" > /dev/null
fi

write_env PGDATA "${DATA_LOCATION}"
write_env POSTGRES_BIN_DIR "${POSTGRES_BIN_DIR}"
write_env POSTGRES_LISTEN_ADDRESSES "${LISTEN_ADDRESSES}"
write_env ADDON_POSTGRES_USER "${POSTGRES_USER}"
write_env ADDON_POSTGRES_PASSWORD "${POSTGRES_PASSWORD}"
write_env ADDON_POSTGRES_DB "${POSTGRES_DB}"
write_env ADDON_POSTGRES_NEW_INSTALL "${NEW_INSTALL}"