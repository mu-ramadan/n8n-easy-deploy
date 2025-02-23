#!/usr/bin/env bash
# install.sh
#
# This script automates the installation of n8n Easy Deploy.
# It will:
# 1. Clone the repository from GitHub (if not already present) to /opt/n8n-easy-deploy.
# 2. Set proper permissions on the main script.
# 3. Create a .env file from .env.example if it doesn't exist.
# 4. Open the .env file for editing using the default editor (with /dev/tty for interactive input).
# 5. Launch the main interactive GUI script.
#
# Usage (run as root via curl):
# sudo curl -sSL https://raw.githubusercontent.com/mu-ramadan/n8n-easy-deploy/refs/heads/main/install.sh | sudo bash

set -Eeuo pipefail

# Configuration
REPO_URL="https://github.com/mu-ramadan/n8n-easy-deploy.git"
REPO_DIR="/opt/n8n-easy-deploy"

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

# Open the .env file for editing using the default editor.
# Using /dev/tty ensures that the editor gets input from the terminal rather than the pipe.
echo "Opening .env file for editing. Please update it with your desired settings and then save and exit the editor."
EDITOR="${EDITOR:-nano}"
$EDITOR .env < /dev/tty

# Confirm with the user that editing is complete
read -rp "Have you saved your changes to .env? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Please edit .env and run this script again."
    exit 1
fi

# Launch the main interactive GUI script
echo "Launching n8n Easy Deploy interactive menu..."
./n8n-easy-deploy.sh
