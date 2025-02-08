#!/bin/bash
set -e

# Source configuration
source ./config.sh

echo "Part 1: Host Preparation"

# System update
echo "Updating system packages..."
apt update
apt upgrade -y

# Install UFW if not present
echo "Installing and configuring firewall (UFW)..."
apt install -y ufw

# Configure firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall if not already enabled
ufw status | grep -q "Status: active" || ufw --force enable

# Create necessary directories
mkdir -p ${CADDY_CONFIG_DIR} ${CADDY_DATA_DIR}
chown -R $SUDO_USER:$SUDO_USER ${CADDY_CONFIG_DIR} ${CADDY_DATA_DIR}

echo "Host preparation complete" 

# Break between steps
echo ""
echo "-----------------------------------"
echo ""

echo "Part 2: Installing Services"

# Install Podman
echo "Installing Podman..."
apt install -y podman

# Install required dependencies
apt install -y uidmap

# Configure podman for rootless operation
echo "Configuring podman for rootless operation..."
usermod --add-subuids 100000-165535 $SUDO_USER
usermod --add-subgids 100000-165535 $SUDO_USER

# Create basic Caddyfile
cat << EOF > ${CADDY_CONFIG_DIR}/Caddyfile
${DOMAIN} {
    respond "Hello, Caddy!"
}
EOF

# Pull and run Caddy container
echo "Setting up Caddy container..."
podman pull docker.io/library/caddy:latest

# Run Caddy container with persistent volumes
podman run -d \
    --name caddy \
    -p 80:80 \
    -p 443:443 \
    -v ${CADDY_CONFIG_DIR}/Caddyfile:/etc/caddy/Caddyfile:Z \
    -v ${CADDY_DATA_DIR}:/data:Z \
    --restart=unless-stopped \
    caddy:latest

echo "Services installation complete" 

# Break between steps
echo ""
echo "-----------------------------------"
echo ""

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