#!/usr/bin/with-contenv bashio
# ==============================================================================
# Seafile CE – Home Assistant Addon entry-point
# Reads addon options, generates config files, then starts all services.
# ==============================================================================
set -e

# ── Paths ──────────────────────────────────────────────────────────────────
SEAFILE_ROOT="/share/seafile"
SEAFILE_DATA="${SEAFILE_ROOT}/seafile-data"
SEAHUB_DATA="${SEAFILE_ROOT}/seahub-data"
CONF_DIR="${SEAFILE_ROOT}/conf"
LOGS_DIR="${SEAFILE_ROOT}/logs"
MYSQL_DATA="/var/lib/mysql"
SEAFILE_SERVER="/opt/seafile"
SEAFILE_SETUP="${SEAFILE_SERVER}/setup-seafile-mysql.sh"
MARKER_FILE="${SEAFILE_ROOT}/.initialized"

mkdir -p "${SEAFILE_DATA}" "${SEAHUB_DATA}" "${CONF_DIR}" "${LOGS_DIR}"

# ── Read options ────────────────────────────────────────────────────────────
bashio::log.info "Reading configuration options…"

SERVER_HOSTNAME=$(bashio::config 'server_hostname')
SERVER_PROTOCOL=$(bashio::config 'server_protocol')
SEAHUB_PORT=$(bashio::config 'seahub_port')
FILESERVER_PORT=$(bashio::config 'fileserver_port')

ADMIN_EMAIL=$(bashio::config 'admin_email')
ADMIN_PASSWORD=$(bashio::config 'admin_password')

JWT_PRIVATE_KEY=$(bashio::config 'jwt_private_key')
SECRET_KEY=$(bashio::config 'secret_key')

MYSQL_ROOT_PASSWORD=$(bashio::config 'mysql_root_password')
MYSQL_HOST=$(bashio::config 'mysql_host')
MYSQL_PORT=$(bashio::config 'mysql_port')
MYSQL_USER=$(bashio::config 'mysql_user')
MYSQL_PASSWORD=$(bashio::config 'mysql_password')
CCNET_DB=$(bashio::config 'ccnet_db_name')
SEAFILE_DB=$(bashio::config 'seafile_db_name')
SEAHUB_DB=$(bashio::config 'seahub_db_name')

CACHE_PROVIDER=$(bashio::config 'cache_provider')
REDIS_HOST=$(bashio::config 'redis_host')
REDIS_PORT=$(bashio::config 'redis_port')
REDIS_PASSWORD=$(bashio::config 'redis_password')
MEMCACHED_HOST=$(bashio::config 'memcached_host')
MEMCACHED_PORT=$(bashio::config 'memcached_port')

TIME_ZONE=$(bashio::config 'time_zone')
ENABLE_NOTIFICATION=$(bashio::config 'enable_notification_server')
NOTIFICATION_URL=$(bashio::config 'notification_server_url')
MD_FILE_LIMIT=$(bashio::config 'md_file_count_limit')
NON_ROOT=$(bashio::config 'non_root')

EMAIL_ENABLED=$(bashio::config 'email_enabled')
EMAIL_HOST=$(bashio::config 'email_host')
EMAIL_PORT=$(bashio::config 'email_port')
EMAIL_USER=$(bashio::config 'email_host_user')
EMAIL_PASS=$(bashio::config 'email_host_password')
EMAIL_USE_TLS=$(bashio::config 'email_use_tls')
EMAIL_FROM=$(bashio::config 'email_from')

S3_ENABLED=$(bashio::config 's3_enabled')
S3_BUCKET=$(bashio::config 's3_bucket')
S3_KEY_ID=$(bashio::config 's3_key_id')
S3_KEY=$(bashio::config 's3_key')
S3_HOST=$(bashio::config 's3_host')
S3_USE_V4=$(bashio::config 's3_use_v4_signature')
S3_PATH_STYLE=$(bashio::config 's3_path_style_request')

SSL_CERT=$(bashio::config 'ssl_cert_path')
SSL_KEY=$(bashio::config 'ssl_key_path')
LOG_LEVEL=$(bashio::config 'log_level')

# Auto-generate secrets if not set
if [ -z "${JWT_PRIVATE_KEY}" ]; then
    JWT_PRIVATE_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    bashio::log.warning "jwt_private_key not set – generated automatically. Set it in options to keep across restarts."
fi
if [ -z "${SECRET_KEY}" ]; then
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
fi

# ── Start MariaDB ────────────────────────────────────────────────────────────
bashio::log.info "Starting MariaDB…"

if [ ! -d "${MYSQL_DATA}/mysql" ]; then
    bashio::log.info "Initialising MariaDB data directory…"
    mysql_install_db --user=mysql --datadir="${MYSQL_DATA}" > /dev/null 2>&1
fi

# Start in background so we can run setup queries
mysqld_safe --datadir="${MYSQL_DATA}" --skip-networking=0 &
MYSQLD_PID=$!

# Wait for MySQL to be ready
bashio::log.info "Waiting for MariaDB to become ready…"
for i in $(seq 1 60); do
    if mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

# ── Start Redis ──────────────────────────────────────────────────────────────
bashio::log.info "Starting Redis…"

REDIS_ARGS=""
if [ -n "${REDIS_PASSWORD}" ]; then
    REDIS_ARGS="--requirepass ${REDIS_PASSWORD}"
fi
redis-server --daemonize yes --port "${REDIS_PORT}" ${REDIS_ARGS}

# ── First-run setup ──────────────────────────────────────────────────────────
if [ ! -f "${MARKER_FILE}" ]; then
    bashio::log.info "First run – setting up Seafile databases and config…"

    # Create MySQL databases and user
    mysql -u root <<SQL
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASSWORD}');
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${CCNET_DB}\` CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS \`${SEAFILE_DB}\` CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS \`${SEAHUB_DB}\` CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON \`${CCNET_DB}\`.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${SEAFILE_DB}\`.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${SEAHUB_DB}\`.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

    # Run Seafile non-interactive setup
    pushd "${SEAFILE_SERVER}" > /dev/null
    ./setup-seafile-mysql.sh auto \
        -n seafile \
        -i "${SERVER_HOSTNAME}" \
        -p "${FILESERVER_PORT}" \
        -d "${SEAFILE_DATA}" \
        -e 1 \
        -o "${MYSQL_HOST}" \
        -t "${MYSQL_PORT}" \
        -u "${MYSQL_USER}" \
        -w "${MYSQL_PASSWORD}" \
        -q "${MYSQL_ROOT_PASSWORD}" \
        -c "${CCNET_DB}" \
        -s "${SEAFILE_DB}" \
        -b "${SEAHUB_DB}" 2>&1 | bashio::log.info
    popd > /dev/null

    touch "${MARKER_FILE}"
    bashio::log.info "First-run setup complete."
fi

# ── Write seahub_settings.py overrides ──────────────────────────────────────
bashio::log.info "Writing Seahub configuration…"

cat > "${CONF_DIR}/seahub_settings.py" <<EOF
# Auto-generated by Seafile HA Addon – do not edit manually.
import os

SECRET_KEY = '${SECRET_KEY}'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': '${SEAHUB_DB}',
        'USER': '${MYSQL_USER}',
        'PASSWORD': '${MYSQL_PASSWORD}',
        'HOST': '${MYSQL_HOST}',
        'PORT': '${MYSQL_PORT}',
    }
}

CACHES = {
EOF

if [ "${CACHE_PROVIDER}" = "redis" ]; then
    REDIS_LOCATION="redis://${REDIS_HOST}:${REDIS_PORT}/1"
    if [ -n "${REDIS_PASSWORD}" ]; then
        REDIS_LOCATION="redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/1"
    fi
    cat >> "${CONF_DIR}/seahub_settings.py" <<EOF
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': '${REDIS_LOCATION}',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
        'TIMEOUT': 300,
    }
EOF
else
    cat >> "${CONF_DIR}/seahub_settings.py" <<EOF
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': '${MEMCACHED_HOST}:${MEMCACHED_PORT}',
    }
EOF
fi

cat >> "${CONF_DIR}/seahub_settings.py" <<EOF
}

TIME_ZONE = '${TIME_ZONE}'
FILE_SERVER_ROOT = '${SERVER_PROTOCOL}://${SERVER_HOSTNAME}/seafhttp'
SITE_BASE = '${SERVER_PROTOCOL}://${SERVER_HOSTNAME}'
SITE_NAME = 'Seafile'
SITE_TITLE = 'Seafile'

# JWT
JWT_PRIVATE_KEY = '${JWT_PRIVATE_KEY}'

# Log level
import logging
LOGGING_LEVEL = logging.${LOG_LEVEL}

EOF

# Email settings
if [ "${EMAIL_ENABLED}" = "true" ]; then
    cat >> "${CONF_DIR}/seahub_settings.py" <<EOF
EMAIL_USE_TLS = ${EMAIL_USE_TLS^}
EMAIL_HOST = '${EMAIL_HOST}'
EMAIL_HOST_USER = '${EMAIL_HOST_USER}'
EMAIL_HOST_PASSWORD = '${EMAIL_PASS}'
EMAIL_PORT = ${EMAIL_PORT}
DEFAULT_FROM_EMAIL = '${EMAIL_FROM}'
SERVER_EMAIL = '${EMAIL_FROM}'
EOF
fi

# Notification server
if [ "${ENABLE_NOTIFICATION}" = "true" ] && [ -n "${NOTIFICATION_URL}" ]; then
    cat >> "${CONF_DIR}/seahub_settings.py" <<EOF
NOTIFICATION_SERVER_URL = '${NOTIFICATION_URL}'
EOF
fi

# Metadata file count limit
cat >> "${CONF_DIR}/seahub_settings.py" <<EOF
MAX_FILE_COUNT_FOR_METADATA = ${MD_FILE_LIMIT}
EOF

# ── Write seafile.conf JWT section ──────────────────────────────────────────
bashio::log.info "Writing seafile.conf…"

cat > "${CONF_DIR}/seafile.conf" <<EOF
[fileserver]
port = ${FILESERVER_PORT}
jwt_private_key = ${JWT_PRIVATE_KEY}

[database]
type = mysql
host = ${MYSQL_HOST}
port = ${MYSQL_PORT}
user = ${MYSQL_USER}
password = ${MYSQL_PASSWORD}
db_name = ${SEAFILE_DB}
connection_charset = utf8
EOF

# ── Configure Nginx ──────────────────────────────────────────────────────────
bashio::log.info "Configuring Nginx…"

if [ "${SERVER_PROTOCOL}" = "https" ] && [ -n "${SSL_CERT}" ] && [ -n "${SSL_KEY}" ]; then
    SSL_BLOCK="
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
"
    LISTEN_LINE="listen ${SEAHUB_PORT} ssl;"
else
    SSL_BLOCK=""
    LISTEN_LINE="listen ${SEAHUB_PORT};"
fi

cat > /etc/nginx/sites-available/seafile.conf <<EOF
log_format seafile '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                   '\$status \$body_bytes_sent "\$http_referer" '
                   '"\$http_user_agent" \$upstream_response_time';

server {
    ${LISTEN_LINE}
    server_name ${SERVER_HOSTNAME};
    ${SSL_BLOCK}

    proxy_set_header X-Forwarded-For \$remote_addr;

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host \$http_host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Host \$server_name;
        proxy_read_timeout 1200s;

        access_log /var/log/nginx/seahub.access.log seafile;
        error_log  /var/log/nginx/seahub.error.log;
    }

    location /seafhttp {
        rewrite ^/seafhttp(.*)$ \$1 break;
        proxy_pass http://127.0.0.1:${FILESERVER_PORT};
        client_max_body_size 0;
        proxy_connect_timeout  36000s;
        proxy_read_timeout     36000s;
        proxy_request_buffering off;
        access_log /var/log/nginx/seafhttp.access.log seafile;
        error_log  /var/log/nginx/seafhttp.error.log;
    }

    location /media {
        root /opt/seafile/seafile-server-latest/seahub;
    }
}
EOF

ln -sf /etc/nginx/sites-available/seafile.conf /etc/nginx/sites-enabled/seafile.conf
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
nginx -t

# ── Start Seafile services ───────────────────────────────────────────────────
bashio::log.info "Starting Seafile server…"
pushd "${SEAFILE_SERVER}" > /dev/null
./seafile.sh start
./seahub.sh start-fastcgi "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}" 2>/dev/null || \
    ./seahub.sh start
popd > /dev/null

# ── Start Nginx ──────────────────────────────────────────────────────────────
bashio::log.info "Starting Nginx…"
nginx

# ── Keep-alive loop ──────────────────────────────────────────────────────────
bashio::log.info "Seafile is running at ${SERVER_PROTOCOL}://${SERVER_HOSTNAME}"

while true; do
    # Health-check: restart Seahub if it died
    if ! pgrep -f "seahub" > /dev/null 2>&1; then
        bashio::log.warning "Seahub process died – restarting…"
        pushd "${SEAFILE_SERVER}" > /dev/null
        ./seahub.sh start
        popd > /dev/null
    fi
    sleep 30
done
