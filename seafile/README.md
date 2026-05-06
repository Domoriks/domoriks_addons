# Home Assistant Add-on: Seafile (Self-contained)

Run Seafile CE with bundled MariaDB and Redis in a single container for LAN use.

## v1 Scope
- **Single container**: Seafile + MariaDB + Redis in one image (no Docker-in-Docker)
- **LAN-only**: Client access on local network
- **Zero external dependencies**: Everything self-contained
- **Minimal configuration**: 3 user settings max
- **ARM64-only**: v1 targets Raspberry Pi / ARM64 systems

## Exposed Settings
- `external_url` (default: `http://127.0.0.1:8000`) — Published URL for Seafile clients
- `admin_email` (default: `admin@example.com`) — Seafile admin login email
- `admin_password` (default: `a_very_secure_password_CHANGEME`) — Seafile admin password

## Startup Behavior
The add-on initializes MariaDB on first start, then uses supervisord to manage three processes:
1. **MariaDB** — database service on localhost:3306
2. **Redis** — cache service on localhost:6379
3. **Seafile** — web server on port 8000

All communication is local (127.0.0.1). No network exposure for DB/Redis.

## First Use
1. Install the add-on in Home Assistant.
2. Ensure `admin_password` is set to something other than the placeholder.
3. Start the add-on.
4. Access Seafile at `http://127.0.0.1:8000`.
5. Log in with the configured `admin_email` and `admin_password`.

## Security Notes
- The default password is a placeholder for rapid testing; **change it immediately in add-on settings before opening to untrusted networks**.
- All services run inside the same container; data is persistent in `/data/seafile-stack`.
- LAN-only (v1) — not suitable for remote access without additional proxy/TLS setup (planned for v2).

## Logs
View logs in Home Assistant add-on panel or via `docker logs` if running standalone.

## Known Limitations (v1)
- **ARM64 only** — amd64 support deferred to v2.
- **LAN only** — no built-in TLS or domain support; use HA reverse proxy if needed.
- **Settings are static** — changes require add-on restart.
- **No migrations** — admin password change requires manual database update if needed.
