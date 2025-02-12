#!/usr/bin/env bash
# install.sh - Automated installer for n8n Easy Deploy
#
# This installer will:
#   - Check for and install required packages: Git, Docker, Docker Compose, AWS CLI, and Caddy.
#   - Clone the repository into a folder named "n8n-easy-deploy" in the current directory.
#   - Set necessary permissions and create required directories.
#   - Prompt the user to update the configuration file (config/.env) with their desired settings.
#   - Launch the main control script if the user chooses to.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/mu-ramadan/n8n-easy-deploy/refs/heads/main/install.sh | bash

# Ensure the script is running under Bash
if [ -z "$BASH_VERSION" ]; then
  echo "This script must be run with Bash. Re-executing using bash..."
  exec /usr/bin/env bash "$0" "$@"
fi

set -Eeuo pipefail

echo "============================================"
echo "          n8n Easy Deploy Installer"
echo "============================================"
echo ""

# Check for Git
if ! command -v git >/dev/null 2>&1; then
  echo "Git is not installed. Please install Git and re-run this script."
  exit 1
fi

# Check for Docker; install if missing
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
fi

# Check for Docker Compose (plugin)
if ! command -v docker-compose >/dev/null 2>&1; then
  echo "Docker Compose not found. Installing Docker Compose plugin..."
  sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# Check for AWS CLI; install if missing
if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI not found. Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip aws
fi

# Check for Caddy; install if missing (Ubuntu/Debian)
if ! command -v caddy >/dev/null 2>&1; then
  echo "Caddy not found. Installing Caddy..."
  sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo apt-key add -
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo apt update
  sudo apt install caddy -y
fi

echo ""
echo "All required packages are installed."
echo ""

# Define repository URL and target directory in the current working directory
REPO_URL="https://github.com/mu-ramadan/n8n-easy-deploy.git"
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
    echo "Please review and update the configuration file with your settings, including DOMAIN_NAME and LETSENCRYPT_EMAIL."
fi

echo ""
echo "============================================"
echo "Installation complete!"
echo "To start n8n Easy Deploy, run:"
echo "  cd $TARGET_DIR"
echo "  ./scripts/n8n-ctl.sh"
echo "============================================"
echo ""
read -rp "Would you like to launch the n8n Easy Deploy menu now? (y/n): " launch_choice
if [[ "$launch_choice" =~ ^[Yy]$ ]]; then
    cd "$TARGET_DIR" && ./scripts/n8n-ctl.sh
else
    echo "You can start n8n Easy Deploy later by navigating to $TARGET_DIR and running ./scripts/n8n-ctl.sh"
fi
