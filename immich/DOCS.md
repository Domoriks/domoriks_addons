# Immich

[Immich](https://immich.app/) is a self-hosted photo and video management platform.

This addon runs the Immich server and a local Redis-compatible cache service.
For the database layer, use the **Postgres for Immich** addon in this repository.

## Installation

1. Install and start **Postgres for Immich** first.
2. Install **Immich**.
3. Configure database connection options in Immich to match Postgres.
4. Start the Immich addon.
5. Open the web UI on port `2283` or via ingress.

## Configuration

| Option | Default | Description |
|---|---|---|
| `upload_location` | `/share/immich/library` | Path for uploaded media |
| `model_cache_location` | `/share/immich/model-cache` | Path for ML model cache |
| `tz` | `UTC` | Time zone for logs/scheduled jobs |
| `db_host` | `postgres` | PostgreSQL host (resolvable hostname or IP, not `*`) |
| `db_port` | `5432` | PostgreSQL port |
| `db_username` | `immich` | PostgreSQL username |
| `db_password` | `immich` | PostgreSQL password |
| `db_database_name` | `immich` | PostgreSQL database name |
| `redis_port` | `6379` | Local Redis-compatible cache port |
| `redis_password` | empty | Cache password (optional) |
| `machine_learning_url` | empty | Optional external machine learning service URL |

## Notes

- This first implementation is CPU-only.
- Data is persisted under `/share/immich` by default.
- If ML features are required, provide an external machine learning URL.
