#!/usr/bin/env bash
# install.sh - Automated installer for n8n Easy Deploy
#
# This script clones the repository into the current directory (as a folder named "n8n-easy-deploy"),
# sets the necessary permissions, creates required directories, and prompts the user to update their configuration.
#
# To install, run:
#   curl -sSL https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh | bash
#
# If you need to run with sudo for parts of the installation, you can use:
#   curl -sSL https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh | sudo bash

# Ensure the script is running under Bash
if [ -z "$BASH_VERSION" ]; then
  echo "This script must be run with Bash. Re-executing using bash..."
  exec /usr/bin/env bash "$0" "$@"
fi

set -Eeuo pipefail

echo "============================================"
echo "  n8n Easy Deploy Installation Script"
echo "============================================"

# Check for required commands
if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is required but not installed. Please install Git and re-run this script."
    exit 1
fi

# Define repository URL and target directory in the current working directory
REPO_URL="https://github.com/yourusername/n8n-easy-deploy.git"
TARGET_DIR="$PWD/n8n-easy-deploy"

# Clone or update the repository
if [ -d "$TARGET_DIR" ]; then
    echo "Repository already exists in $TARGET_DIR."
    read -rp "Do you want to update the repository? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Updating repository..."
        cd "$TARGET_DIR" && git pull || { echo "Error: git pull failed."; exit 1; }
    else
        echo "Skipping update. Installation will proceed with the existing repository."
    fi
else
    echo "Cloning repository into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR" || { echo "Error: Cloning failed."; exit 1; }
fi

# Set file permissions for the main control script
echo "Setting file permissions..."
chmod +x "$TARGET_DIR/scripts/n8n-ctl.sh"

# Create required directories if they don't exist
echo "Creating backups and logs directories..."
mkdir -p "$TARGET_DIR/backups" "$TARGET_DIR/logs"

# Ensure configuration file exists
CONFIG_FILE="$TARGET_DIR/config/.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating from sample (.env.example)..."
    cp "$TARGET_DIR/config/.env.example" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE."
    echo "Please review and update the configuration file with your settings."
fi

echo "============================================"
echo "Installation complete!"
echo "To start n8n Easy Deploy, execute the following commands:"
echo "  cd $TARGET_DIR"
echo "  ./scripts/n8n-ctl.sh"
echo "============================================"
