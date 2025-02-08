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