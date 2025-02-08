# Podman, Caddy & Linux VM Automation Experiment

This project is an experiment in automating a bare‑bones Linux VPS to host a static website using Podman and Caddy. 
Over several days of collaboration and experimentation (with a lot of help from OpenAI and Cursor), I refined a series of scripts that get the site online—from initial host setup to full deployment.

## Project Goal

*To deploy a static website on a Linux VPS using Podman and Caddy—from scratch, using a single script or a set of smaller, modular scripts.*

## Assumptions

- You have a Linux virtual machine (VM) hosted on a cloud service provider.
- You have SSH access to the machine.
- Your login credentials are readily available.
- This example uses Ubuntu 24.04 on a Small Shared Linode, but the instructions should be adaptable to other distributions or Cloud platforms

## Setup Options

You can choose one of two approaches:

### Option 1: Modular Scripts

For a step-by-step approach, use the following smaller scripts:

- **01_prep_host.sh**  
  *Prepares the host by updating the system, configuring the firewall, and installing Podman if needed.*

- **02_install_services.sh**  
  *Installs and configures necessary services (including Caddy) on the VM.*

- **03_verify_setup.sh**  
  *Validates the Caddyfile, checks TLS connectivity, and ensures the website is accessible.*

- **config.sh**  
  *Contains configuration variables used by the other scripts.*

### Option 2: One Script to Rule Them All

- **full_prep.sh**  
  *This single script automates the full setup process from initial host preparation to launching Caddy and verifying TLS connectivity.*

## Usage Notes

1. **Make Scripts Executable:**  
   Ensure each script is executable by running:
   ```bash
   chmod +x <script_name>



