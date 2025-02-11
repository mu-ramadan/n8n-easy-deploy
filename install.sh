#!/usr/bin/env bash
# install.sh - Automated installer for n8n Easy Deploy
#
# This script clones the repository to a default location,
# sets the necessary permissions, creates required directories,
# and prompts the user to update their configuration if needed.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# After installation, follow the instructions to edit the config file
# and then run the main control script:
#   cd /opt/n8n-easy-deploy && ./scripts/n8n-ctl.sh

set -Eeuo pipefail

echo "============================================"
echo "  n8n Easy Deploy Installation Script"
echo "============================================"

# Check for required commands
if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is required but not installed. Please install Git and re-run this script."
    exit 1
fi

# Define repository URL and target installation directory
REPO_URL="https://github.com/yourusername/n8n-easy-deploy.git"
INSTALL_DIR="/opt/n8n-easy-deploy"

# Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Repository already exists in $INSTALL_DIR."
    read -rp "Do you want to update the repository? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Updating repository..."
        cd "$INSTALL_DIR" && git pull || { echo "Error: git pull failed."; exit 1; }
    else
        echo "Skipping update. Installation will proceed with the existing repository."
    fi
else
    echo "Cloning repository to $INSTALL_DIR..."
    sudo git clone "$REPO_URL" "$INSTALL_DIR" || { echo "Error: Cloning failed."; exit 1; }
fi

# Change ownership and set permissions for the installation directory
echo "Setting file permissions..."
sudo chown -R "$USER":"$USER" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/scripts/n8n-ctl.sh"

# Create required directories if they don't exist
echo "Creating backups and logs directories..."
mkdir -p "$INSTALL_DIR/backups" "$INSTALL_DIR/logs"

# Ensure configuration file exists
CONFIG_FILE="$INSTALL_DIR/config/.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating from sample (.env.example)..."
    cp "$INSTALL_DIR/config/.env.example" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE."
    echo "Please review and update the configuration file with your settings."
fi

echo "============================================"
echo "Installation complete!"
echo "To start n8n Easy Deploy, execute the following commands:"
echo "  cd $INSTALL_DIR"
echo "  ./scripts/n8n-ctl.sh"
echo "============================================"
