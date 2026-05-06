#!/usr/bin/with-contenv bashio
set -euo pipefail

STACK_DIR="/data/seafile-stack"
ENV_FILE="${STACK_DIR}/.env"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

set_env_value() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "${ENV_FILE}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
    else
        echo "${key}=${value}" >> "${ENV_FILE}"
    fi
}

EXTERNAL_URL="$(bashio::config 'external_url')"
if [ -z "${EXTERNAL_URL}" ]; then
    EXTERNAL_URL="http://homeassistant.local:8000"
fi

ADMIN_EMAIL="$(bashio::config 'admin_email')"
if [ -z "${ADMIN_EMAIL}" ]; then
  ADMIN_EMAIL="admin@example.com"
fi

ADMIN_PASSWORD="$(bashio::config 'admin_password')"
if [ -z "${ADMIN_PASSWORD}" ]; then
  ADMIN_PASSWORD="a_very_secure_password_CHANGEME"
fi

URL_NO_SCHEME="${EXTERNAL_URL#http://}"
URL_NO_SCHEME="${URL_NO_SCHEME#https://}"
HOST_WITH_PORT="${URL_NO_SCHEME%%/*}"
HOSTNAME_ONLY="${HOST_WITH_PORT%%:*}"
PORT_ONLY="${HOST_WITH_PORT##*:}"

if [ "${HOST_WITH_PORT}" = "${PORT_ONLY}" ]; then
    PORT_ONLY="8000"
fi

if [ -z "${HOSTNAME_ONLY}" ]; then
    HOSTNAME_ONLY="homeassistant.local"
fi

mkdir -p "${STACK_DIR}"

if [ ! -f "${ENV_FILE}" ]; then
    cat > "${ENV_FILE}" <<'EOF'
DB_ROOT_PASSWD=a_very_secure_password_CHANGEME
SEAFILE_ADMIN_EMAIL=admin@example.com
SEAFILE_ADMIN_PASSWORD=a_very_secure_password_CHANGEME
SEAFILE_SERVER_HOSTNAME=homeassistant.local
SEAFILE_SERVER_PROTOCOL=http
SEAFILE_PUBLISH_PORT=8000
EOF
fi

set_env_value "SEAFILE_SERVER_HOSTNAME" "${HOSTNAME_ONLY}"
set_env_value "SEAFILE_SERVER_PROTOCOL" "http"
set_env_value "SEAFILE_PUBLISH_PORT" "${PORT_ONLY}"
set_env_value "SEAFILE_ADMIN_EMAIL" "${ADMIN_EMAIL}"
set_env_value "SEAFILE_ADMIN_PASSWORD" "${ADMIN_PASSWORD}"

if [ ! -f "${COMPOSE_FILE}" ]; then
    cat > "${COMPOSE_FILE}" <<'EOF'
services:
  db:
    image: mariadb:10.11
    container_name: seafile-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWD}
      - MYSQL_LOG_CONSOLE=true
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:7-alpine
    container_name: seafile-redis
    restart: unless-stopped
    volumes:
      - ./redis:/data

  seafile:
    image: seafileltd/seafile-mc:13.0-latest
    container_name: seafile-server
    restart: unless-stopped
    depends_on:
      - db
      - redis
    ports:
      - "${SEAFILE_PUBLISH_PORT}:80"
    environment:
      - DB_HOST=db
      - DB_ROOT_PASSWD=${DB_ROOT_PASSWD}
      - TIME_ZONE=Etc/UTC
      - SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL}
      - SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}
      - SEAFILE_SERVER_LETSENCRYPT=false
      - SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}
      - SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL}
    volumes:
      - ./seafile-data:/shared
EOF
fi

if [ "${ADMIN_PASSWORD}" = "a_very_secure_password_CHANGEME" ]; then
  bashio::log.warning "Using placeholder admin password in ${ENV_FILE}. Change CHANGEME value after testing."
fi
bashio::log.info "External URL: ${EXTERNAL_URL}"
bashio::log.info "Seafile publish endpoint: http://${HOSTNAME_ONLY}:${PORT_ONLY}"

# Home Assistant usually exposes Docker socket at /run/docker.sock.
if [ -S /run/docker.sock ]; then
  export DOCKER_HOST="unix:///run/docker.sock"
elif [ -S /var/run/docker.sock ]; then
  export DOCKER_HOST="unix:///var/run/docker.sock"
else
  bashio::log.error "No Docker socket found (/run/docker.sock or /var/run/docker.sock)."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  bashio::log.error "Docker daemon unreachable via ${DOCKER_HOST}."
  exit 1
fi

cd "${STACK_DIR}"
docker compose up -d

cleanup() {
    bashio::log.info "Stopping Seafile stack"
    docker compose down || true
    exit 0
}

trap cleanup TERM INT

docker compose logs --no-color --follow seafile
