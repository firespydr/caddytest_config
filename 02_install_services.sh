#!/bin/bash
set -e

# Source configuration
source ./config.sh

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