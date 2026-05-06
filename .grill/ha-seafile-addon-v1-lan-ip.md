# Grill: HA Seafile Add-on V1 LAN/IP
Date: 2026-05-06

## Intent
Create a Home Assistant add-on for Seafile that works immediately for LAN clients with minimal setup and minimal user-facing settings.

## Constraints
- Full self-contained stack required (Seafile + DB + Redis).
- Client connectivity must work from first start.
- LAN-only scope for V1.
- No random secrets for V1 bootstrap.
- Use placeholder credentials for rapid testing.
- Keep HA settings minimal.

## Key decisions
- Decision: Use direct IP URL approach, not ingress-only. Reason: desktop/mobile Seafile clients must connect from day one. Alternative considered: ingress-only access.
- Decision: LAN-only V1. Reason: reduce setup complexity and deliver fast first working version. Alternative considered: remote/NAT/domain setup in V1.
- Decision: Fixed placeholder password `a_very_secure_password_CHANGEME`. Reason: rapid testing without setup friction. Alternative considered: random generation on first boot.
- Decision: Add-on auto-starts with placeholders and warnings. Reason: immediate usability. Alternative considered: blocking startup until credentials changed.
- Decision: Expose only one setting (`external_url`) with default `http://homeassistant.local:8000`. Reason: minimal user configuration. Alternative considered: exposing multiple DB/Redis/admin settings.

## Surfaced assumptions
- Seafile client behavior needs stable direct URL and is not reliably served by HA ingress path/session model.
- Placeholder credentials are acceptable in initial LAN test environment.
- Internal DB and Redis can be managed by addon runtime orchestration.

## Out of scope
- Internet exposure, TLS, and domain automation.
- Optional Seafile services (SeaDoc, AI, metadata, notification).
- Strict credential enforcement in V1.
