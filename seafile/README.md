# Home Assistant Add-on: Seafile (Self-contained)

Run Seafile CE with internal MariaDB and Redis managed by the add-on.

## Scope (v1)
- LAN use only
- Client access from start
- Minimal user settings
- Placeholder credentials for rapid testing

## Exposed settings
- `external_url` (default: `http://homeassistant.local:8000`)
- `admin_email` (default: `admin@example.com`)
- `admin_password` (default: `a_very_secure_password_CHANGEME`)

## Default bootstrap credentials and secrets
The add-on creates `/data/seafile-stack/.env` on first start with placeholders:

- `DB_ROOT_PASSWD=a_very_secure_password_CHANGEME`
- `SEAFILE_ADMIN_EMAIL` (from `admin_email` setting)
- `SEAFILE_ADMIN_PASSWORD` (from `admin_password` setting)

Change these values after first boot.

## Client URL
Use the same URL as `external_url` (for LAN default: `http://homeassistant.local:8000`).

## Notes
- This add-on uses Docker API to start an internal Seafile stack.
- Services started: Seafile, MariaDB, Redis.
