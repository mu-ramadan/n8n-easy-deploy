#!/usr/bin/env bash
# install.sh
#
# This script automates the installation of n8n Easy Deploy.
# It will:
# 1. Check for an interactive terminal.
# 2. Clone the repository from GitHub (if not already present) into /opt/n8n-easy-deploy.
# 3. Set proper permissions on the main script.
# 4. Create a .env file from .env.example if it doesn't exist.
# 5. Open the .env file for editing.
# 6. Launch the main interactive GUI.
#
# Usage (run as root):
# sudo curl -sSL https://raw.githubusercontent.com/mu-ramadan/n8n-easy-deploy/refs/heads/main/install.sh | sudo bash

set -Eeuo pipefail

# Check for interactive terminal
if [ ! -t 0 ]; then
  echo "Error: This script requires an interactive terminal."
  echo "Please run it with an interactive shell (e.g., sudo bash -i install.sh)."
  exit 1
fi

# Configuration
REPO_URL="https://github.com/mu-ramadan/n8n-easy-deploy.git"
REPO_DIR="/opt/n8n-easy-deploy"  # Repository will be cloned here

echo "n8n Easy Deploy Installer"
echo "=========================="

# Clone the repository if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning repository from $REPO_URL to $REPO_DIR..."
    git clone "$REPO_URL" "$REPO_DIR" || { echo "Failed to clone repository."; exit 1; }
else
    echo "Repository already exists at $REPO_DIR."
fi

cd "$REPO_DIR" || { echo "Cannot change directory to $REPO_DIR"; exit 1; }

# Ensure the main script is executable
chmod +x n8n-easy-deploy.sh

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env || { echo "Failed to create .env file."; exit 1; }
    chmod 600 .env
fi

# Open the .env file for editing
echo "Opening .env file for editing. Please update it with your desired settings."
# Use the default editor ($EDITOR) or fallback to nano
EDITOR="${EDITOR:-nano}"
$EDITOR .env

# Confirm with the user that editing is complete
read -rp "Have you saved your changes to .env? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Please edit .env and run this script again."
    exit 1
fi

# Launch the main interactive GUI script
echo "Launching n8n Easy Deploy interactive menu..."
./n8n-easy-deploy.sh
