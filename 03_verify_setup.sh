#!/bin/bash
set -e

# Source shared configuration variables
source ./config.sh

echo "Part 3: Verification"

# Check that ports 80 and 443 are open
echo "Checking open ports (80 and 443):"
ss -tulpn | grep -E ':80|:443' || echo "Ports 80/443 not detected."

echo ""
# Check status of the Caddy container
echo "Checking Caddy container status:"
podman ps | grep caddy || echo "Caddy container is not running."

echo ""
# Verify the content of the Caddyfile
echo "Verifying Caddyfile content:"
if [ -f "${CADDY_CONFIG_DIR}/Caddyfile" ]; then
    cat "${CADDY_CONFIG_DIR}/Caddyfile"
else
    echo "Caddyfile not found at ${CADDY_CONFIG_DIR}/Caddyfile"
fi

echo ""
# TLS check with curl against your domain
echo "Performing TLS check with curl against https://${DOMAIN}:"
curl -I "https://${DOMAIN}" || echo "TLS check failed for ${DOMAIN}"

echo ""
# Generate the final verification report
REPORT="setup_report.txt"
{
    echo "Setup Verification Report"
    echo "-------------------------"
    echo "Date: $(date)"
    echo ""
    echo "Podman version:"
    podman --version
    echo ""
    echo "Caddy Container Status:"
    podman ps | grep caddy || echo "Caddy container is not running."
    echo ""
    echo "Open Ports (filtered for 80 and 443):"
    ss -tulpn | grep -E ':80|:443'
    echo ""
    echo "Caddyfile Content:"
    if [ -f "${CADDY_CONFIG_DIR}/Caddyfile" ]; then
        cat "${CADDY_CONFIG_DIR}/Caddyfile"
    else
        echo "Caddyfile not found at ${CADDY_CONFIG_DIR}/Caddyfile"
    fi
    echo ""
    echo "TLS Check (curl -I https://${DOMAIN}):"
    curl -I "https://${DOMAIN}" || echo "TLS check failed for ${DOMAIN}"
} > "${REPORT}"

echo "Verification complete. Report saved to ${REPORT}" 