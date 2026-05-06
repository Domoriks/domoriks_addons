ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    redis-server \
    supervisor \
    curl \
    bash \
    coreutils \
    grep \
    sed \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /var/log/mysql /var/run/mysqld /opt && \
    chown mysql:mysql /var/run/mysqld /var/log/mysql

COPY rootfs /
RUN chmod a+x /run.sh /opt/seafile-init.sh

EXPOSE 8000 8082 3306 6379

CMD ["/run.sh"]
