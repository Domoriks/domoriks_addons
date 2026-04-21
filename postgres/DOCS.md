# Postgres for Immich

This addon provides a PostgreSQL database intended for the Immich addon.

## Installation

1. Install the **Postgres for Immich** addon.
2. Set a strong `postgres_password`.
3. Start the addon.
4. Note the host and port reachable by your Immich addon.

## Configuration

| Option | Default | Description |
|---|---|---|
| `data_location` | `/share/postgres/data` | Database data directory |
| `postgres_user` | `immich` | PostgreSQL username |
| `postgres_password` | `immich` | PostgreSQL password |
| `postgres_db` | `immich` | PostgreSQL database name |
| `listen_addresses` | `*` | PostgreSQL listen addresses (`*`, `localhost`, or IPs; hostnames are not supported) |

## Notes

- Data is persisted under `/share/postgres` by default.
- Exposes PostgreSQL on port `5432`.
