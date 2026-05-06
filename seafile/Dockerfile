ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    redis-server \
    curl \
    jq \
    bash \
    coreutils \
    grep \
    sed \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/mysql /var/run/mysqld /opt && \
    chown mysql:mysql /var/run/mysqld /var/log/mysql

COPY rootfs /

# Patch upstream setup to accept single-label hostnames (e.g., 'gas1c') for LAN use.
# The validation rejects hostnames without dots. Patch both shell and Python scripts.
RUN for file in $(find /scripts /opt/seafile -type f \( -name "*.py" -o -name "*.sh" \) 2>/dev/null); do \
    sed -i \
        -e "s/if not is_valid(ip_or_domain)/if False/" \
        -e "s/return '\\.' in ip_or_domain/return True/" \
        -e "s/if '\\.' not in ip_or_domain/if False/" \
        -e "s/is not a valid ip or domain/is valid for LAN/" \
        -e "s/'is not a valid ip or domain'/'is valid for LAN'/" \
        "$file" 2>/dev/null || true; \
    done

# Create runit service scripts for MariaDB and Redis.
# These cannot be COPY'd because /etc/service already exists in the base image.
RUN mkdir -p /etc/service/mariadb && printf '#!/bin/bash\nexec /usr/sbin/mysqld --user=mysql --datadir=/var/lib/mysql --socket=/var/run/mysqld/mysqld.sock --bind-address=127.0.0.1\n' > /etc/service/mariadb/run

RUN mkdir -p /etc/service/redis && printf '#!/bin/bash\nexec /usr/bin/redis-server --bind 127.0.0.1 --port 6379 --daemonize no --loglevel notice\n' > /etc/service/redis/run

RUN chmod a+x \
    /run.sh \
    /opt/seafile-init.sh \
    /etc/service/mariadb/run \
    /etc/service/redis/run

EXPOSE 80 8082

CMD ["/run.sh"]
