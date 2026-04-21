# Seafile CE – Home Assistant Addon

[Seafile](https://www.seafile.com) is an open-source, self-hosted file sync and share platform.
This addon runs **Seafile Community Edition** directly on your Home Assistant OS instance.

---

## What's included

| Service | Notes |
|---------|-------|
| **Seahub** | Web interface (default port 80) |
| **Seafile file-server** | Desktop / mobile sync + WebDAV (default port 8082) |
| **MariaDB** | Bundled database — data persists in `/share/seafile` |
| **Redis** | Bundled cache — strongly recommended for Seafile 13+ |
| **Nginx** | Reverse proxy that ties the above together |

---

## Installation

1. Add this repository to your Home Assistant addon store.
2. Install the **Seafile** addon.
3. Fill in at minimum:
   - `server_hostname` – the hostname/IP HA will be reached at
   - `admin_email` and `admin_password`
   - `mysql_root_password` and `mysql_password`
4. Click **Start**.
5. Open the web UI via the **Open Web UI** button or navigate to `http://<HA-IP>`.

> **First run** takes ~60 seconds while databases are initialised.

---

## Configuration options

### Server

| Option | Default | Description |
|--------|---------|-------------|
| `server_hostname` | `homeassistant.local` | Public hostname or IP of your HA instance |
| `server_protocol` | `http` | `http` or `https` |
| `seahub_port` | `80` | Port for the Seahub web UI |
| `fileserver_port` | `8082` | Port for the Seafile file-server |

### Admin account *(first run only)*

| Option | Default | Description |
|--------|---------|-------------|
| `admin_email` | `admin@example.com` | Administrator e-mail address |
| `admin_password` | `changeme` | Administrator password — **change this!** |

### Security

| Option | Default | Description |
|--------|---------|-------------|
| `jwt_private_key` | *(auto-generated)* | JWT signing secret – set once and never change |
| `secret_key` | *(auto-generated)* | Django CSRF secret |

### Database

| Option | Default | Description |
|--------|---------|-------------|
| `mysql_root_password` | `seafile_root` | MariaDB root password |
| `mysql_host` | `127.0.0.1` | Database host (use `127.0.0.1` for bundled) |
| `mysql_port` | `3306` | Database port |
| `mysql_user` | `seafile` | Database user |
| `mysql_password` | `seafile` | Database user password |
| `ccnet_db_name` | `ccnet_db` | ccnet database name |
| `seafile_db_name` | `seafile_db` | seafile database name |
| `seahub_db_name` | `seahub_db` | seahub database name |

### Cache

| Option | Default | Description |
|--------|---------|-------------|
| `cache_provider` | `redis` | `redis` (recommended) or `memcached` |
| `redis_host` | `127.0.0.1` | Redis host |
| `redis_port` | `6379` | Redis port |
| `redis_password` | *(none)* | Optional Redis password |
| `memcached_host` | `127.0.0.1` | Memcached host (when `cache_provider` = `memcached`) |
| `memcached_port` | `11211` | Memcached port |

### Time

| Option | Default | Description |
|--------|---------|-------------|
| `time_zone` | `UTC` | IANA time zone, e.g. `Europe/Berlin` |

### Optional features

| Option | Default | Description |
|--------|---------|-------------|
| `enable_notification_server` | `false` | Enable real-time push notifications |
| `notification_server_url` | *(none)* | URL of a running Seafile notification server |
| `md_file_count_limit` | `100000` | Max files per repo for metadata management |
| `non_root` | `false` | Run container processes as non-root |

### Outbound e-mail

| Option | Default | Description |
|--------|---------|-------------|
| `email_enabled` | `false` | Enable SMTP |
| `email_host` | *(none)* | SMTP server hostname |
| `email_port` | `587` | SMTP port |
| `email_host_user` | *(none)* | SMTP username |
| `email_host_password` | *(none)* | SMTP password |
| `email_use_tls` | `true` | Enable STARTTLS |
| `email_from` | *(none)* | From address for outgoing mail |

### S3 / Object-storage backend

| Option | Default | Description |
|--------|---------|-------------|
| `s3_enabled` | `false` | Store blocks in S3-compatible object store |
| `s3_bucket` | *(none)* | S3 bucket name |
| `s3_key_id` | *(none)* | S3 access key ID |
| `s3_key` | *(none)* | S3 secret access key |
| `s3_host` | *(none)* | S3 endpoint (blank = AWS S3) |
| `s3_use_v4_signature` | `true` | Use AWS v4 request signing |
| `s3_path_style_request` | `false` | Use path-style bucket URLs (MinIO etc.) |

### HTTPS / TLS

| Option | Default | Description |
|--------|---------|-------------|
| `ssl_cert_path` | *(none)* | Path to PEM certificate (when `server_protocol` = `https`) |
| `ssl_key_path` | *(none)* | Path to PEM private key |

### Logging

| Option | Default | Description |
|--------|---------|-------------|
| `log_level` | `INFO` | `DEBUG`, `INFO`, `WARNING`, or `ERROR` |

---

## Data persistence

All Seafile data, configuration files, and logs are stored under `/share/seafile`:

```
/share/seafile/
├── seafile-data/      # File blocks + configuration
├── seahub-data/       # Seahub avatars & user uploads
├── conf/              # Generated config files (seahub_settings.py, seafile.conf, …)
└── logs/              # Application logs
```

MariaDB data lives in `/var/lib/mysql` inside the container (persisted via the addon data layer).

---

## Backup

Back up `/share/seafile` and the MariaDB data directory.  
Refer to the [official Seafile backup guide](https://manual.seafile.com/latest/administration/backup_recovery/).

---

## Upgrading

1. Update the addon version.
2. The startup script detects the existing installation (`.initialized` marker) and skips first-run setup.
3. Seahub auto-migrates the database on first start after a version bump.

---

## Support

- [Seafile documentation](https://manual.seafile.com)
- [Seafile community forum](https://forum.seafile.com)
