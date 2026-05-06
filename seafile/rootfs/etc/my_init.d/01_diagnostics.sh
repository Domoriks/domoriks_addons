#!/bin/bash
# Diagnostic script: log nginx config and service status
# Runs early in my_init.d to capture baseline state

echo ""
echo "=========================================="
echo "  DIAGNOSTICS: Nginx Configuration"
echo "=========================================="
echo ""

# Check nginx version
echo "[NGINX] Version:"
nginx -v 2>&1 || echo "  (nginx not found)"
echo ""

# Test nginx config syntax
echo "[NGINX] Configuration test:"
nginx -t 2>&1 || true
echo ""

# Show what ports are being listened on
echo "[NGINX] Listening ports (from config):"
grep -r "listen" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | head -20 || echo "  (no listen directives found)"
echo ""

# Show server blocks
echo "[NGINX] Server blocks:"
grep -r "server {" -A 3 /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | head -30 || echo "  (no server blocks found)"
echo ""

# Check if upstream servers are defined
echo "[NGINX] Upstream definitions:"
grep -r "upstream" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | head -20 || echo "  (no upstreams defined)"
echo ""

echo "=========================================="
echo ""
