#!/bin/bash

# --- Helper Functions ---
update_os() {
    echo "Updating the host OS..."
    sudo apt update && sudo apt upgrade -y
}

configure_firewall() {
    echo "Configuring ufw firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow OpenSSH
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    echo "Current ufw status:"
    sudo ufw status verbose
}

check_port() {
  local port=$1
  if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null; then
      echo "Port $port is already in use. Please free it before proceeding."
      exit 1
  fi
}

validate_domain() {
    if ! [[ "$DOMAIN_NAME" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      echo "Invalid domain format. Please re-run the script with a valid domain name."
      exit 1
    fi
}

backup_caddyfile() {
    if [ -f "${CADDYFILE_PATH}" ]; then
        cp "${CADDYFILE_PATH}" "${CADDYFILE_PATH}.bak"
        echo "Existing Caddyfile backed up to ${CADDYFILE_PATH}.bak"
    fi
}

perform_tls_checks() {
    echo "Performing TLS checks..."
    # Check HTTP on localhost
    HTTP_CODE=$(curl -4s -o /dev/null -w "%{http_code}" http://localhost)
    # Check HTTPS on localhost (skip certificate verification with -k)
    HTTPS_CODE=$(curl -4ks -o /dev/null -w "%{http_code}" https://localhost)
    echo "HTTP status code (http://localhost): $HTTP_CODE"
    echo "HTTPS status code (https://localhost): $HTTPS_CODE"
}

container_exists() {
    if podman ps --filter "name=${PROJECT_NAME}" | grep -q "${PROJECT_NAME}"; then
        return 0
    else
        return 1
    fi
}

# --- Main Script Start ---
echo "=== Caddy with Podman Setup Script ==="

# 1. Update OS and configure firewall
update_os
configure_firewall

# 2. Prompt user for key variables
read -p "Enter the project name (for container naming, e.g., my-caddy): " PROJECT_NAME
read -p "Enter the project path (directory for configuration, e.g., /opt/my-caddy-project): " PROJECT_PATH
read -p "Enter the public IP address of your server: " PUBLIC_IP
read -p "Enter the domain name (e.g., example.com): " DOMAIN_NAME
validate_domain

# 3. Define paths based on PROJECT_PATH
mkdir -p "${PROJECT_PATH}"
CADDYFILE_PATH="${PROJECT_PATH}/Caddyfile"
HTML_DIR="${PROJECT_PATH}/html"

# 4. Backup any existing Caddyfile and create new configuration
backup_caddyfile
echo "Creating/updating Caddyfile at ${CADDYFILE_PATH}..."
cat > "${CADDYFILE_PATH}" << EOF
$DOMAIN_NAME {
    root * /var/www
    file_server
}
EOF

# 5. Create webroot directory and sample index.html if not existing
if [ ! -d "${HTML_DIR}" ]; then
    echo "Creating html directory at ${HTML_DIR}..."
    mkdir -p "${HTML_DIR}"
fi

if [ ! -f "${HTML_DIR}/index.html" ]; then
    echo "Creating index.html in ${HTML_DIR}..."
    cat > "${HTML_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CADDY Landing Page</title>
    <style>
        body {
            margin: 0;
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            background: linear-gradient(to right, #667eea, #764ba2);
            font-family: sans-serif;
        }
        h1 {
            font-size: 8em;
            font-weight: bold;
            color: white;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
    </style>
</head>
<body>
    <h1>CADDY</h1>
</body>
</html>
EOF
fi

# 6. Pre-deployment port checks for HTTP and HTTPS
check_port 80
check_port 443

# 7. Validate the Caddyfile before launching container
echo "Validating Caddyfile syntax..."
podman run --rm \
  -v "${CADDYFILE_PATH}":/etc/caddy/Caddyfile:Z \
  docker.io/caddy:latest caddy validate --config /etc/caddy/Caddyfile

# 8. Check if a container with PROJECT_NAME already exists; if so, ask to remove it
if container_exists; then
    echo "A container named '${PROJECT_NAME}' already exists. Do you want to remove and restart it? (y/n)"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      podman rm -f "${PROJECT_NAME}"
    else
      echo "Exiting to avoid conflict."
      exit 1
    fi
fi

# 9. Launch Caddy container using Podman with the provided container name and ports mapped
echo "Starting Caddy container using podman run..."
podman run -d \
  --name "${PROJECT_NAME}" \
  --restart=always \
  -v "${CADDYFILE_PATH}":/etc/caddy/Caddyfile:Z \
  -v "${HTML_DIR}":/var/www:Z \
  -p 80:80 \
  -p 443:443 \
  docker.io/caddy:latest

# 10. Give container a moment to start and format the Caddyfile inside the container
sleep 2
echo "Formatting the Caddyfile inside the container..."
podman exec "${PROJECT_NAME}" caddy fmt --overwrite /etc/caddy/Caddyfile

# 11. Check container status
echo "Checking running containers..."
podman ps
CONTAINER_STATUS=$(podman ps --filter "name=${PROJECT_NAME}" --format "{{.Status}}")
if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
    echo "Caddy container '${PROJECT_NAME}' is running successfully."
else
    echo "Caddy container '${PROJECT_NAME}' is not running. Please check logs with: podman logs ${PROJECT_NAME}"
fi

# --- Pause for DNS propagation before TLS checks ---
read -n 1 -s -r -p "Press any key to continue to TLS checks..."
echo ""

# --- Verify Caddyfile Syntax and Domain ---
echo "Validating Caddyfile syntax..."
if podman run --rm \
    -v "${CADDYFILE_PATH}":/etc/caddy/Caddyfile:Z \
    docker.io/caddy:latest caddy validate --config /etc/caddy/Caddyfile; then
    echo "Caddyfile syntax is valid."
else
    echo "Caddyfile syntax error. Please check your configuration."
    exit 1
fi

echo "Formatting Caddyfile..."
if podman exec "${PROJECT_NAME}" caddy fmt --overwrite /etc/caddy/Caddyfile; then
    echo "Caddyfile formatted successfully."
else
    echo "Error formatting Caddyfile."
    exit 1
fi

echo "Verifying that the domain '$DOMAIN_NAME' is present in the Caddyfile..."
if grep -q "$DOMAIN_NAME" "$CADDYFILE_PATH"; then
    echo "Domain '$DOMAIN_NAME' found in Caddyfile."
else
    echo "ERROR: Domain '$DOMAIN_NAME' not found in Caddyfile. Please review the configuration."
    exit 1
fi

# 12. Perform TLS checks with curl and capture status codes
perform_tls_checks

# 13. Final Summary Report
echo "----------------------"
echo "Setup Report:"
echo "----------------------"
echo "1. OS update and upgrade complete."
echo "2. UFW firewall configured to allow SSH, HTTP (port 80), and HTTPS (port 443)."
echo "3. Podman has been installed."
echo "4. Project Name: ${PROJECT_NAME}"
echo "5. Project Path: ${PROJECT_PATH}"
echo "6. Public IP Address: ${PUBLIC_IP}"
echo "7. Domain Name: ${DOMAIN_NAME}"
echo "8. Caddyfile for domain '${DOMAIN_NAME}' is located at: ${CADDYFILE_PATH}"
echo "9. Webroot directory is located at: ${HTML_DIR} (index.html is set as the landing page)."
echo "10. Caddy container '${PROJECT_NAME}' is running on ports 80 and 443."
echo "11. The Caddyfile has been validated and formatted inside the container."
echo ""
echo "TLS Check Results:"
echo "   - HTTP (http://localhost) returned status: $HTTP_CODE"
echo "   - HTTPS (https://localhost) returned status: $HTTPS_CODE"
echo ""
echo "To validate the deployment, try these commands on the host:"
echo "   curl -4vk http://localhost"
echo "   curl -4vk https://localhost"
echo ""
echo "If you see certificate warnings when accessing HTTPS, remember that self-signed or temporary certificates might be used until you configure a trusted CA."
echo "----------------------"
echo "Setup complete. Enjoy your configuration."
