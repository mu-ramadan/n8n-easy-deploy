#!/usr/bin/env bash
# install.sh
#
# n8n Easy Deploy Installer
# This script automates the complete installation of n8n Easy Deploy.
# It will:
# 1. Check for and install all required software (Git, Docker, Docker Compose, AWS CLI).
# 2. Import the missing GPG key for the Caddy repository using the new keyring method.
# 3. Remove any existing repository at /opt/n8n-easy-deploy and clone the repository from GitHub.
# 4. Set proper permissions on the main script.
# 5. Create a .env file from .env.example if it doesn't exist.
# 6. Open the .env file for editing so the user can update settings (using /dev/tty for interactive input).
# 7. Launch the main interactive GUI.
#
# Usage (run via curl as root):
# sudo curl -sSL https://raw.githubusercontent.com/mu-ramadan/n8n-easy-deploy/refs/heads/main/install.sh | sudo bash

set -Eeuo pipefail

# Configuration
REPO_URL="https://github.com/mu-ramadan/n8n-easy-deploy.git"
REPO_DIR="/opt/n8n-easy-deploy"

echo "n8n Easy Deploy Installer"
echo "=========================="

# ---------------------------
# Install Required Software
# ---------------------------
echo "Checking required software..."

# Git
if ! command -v git >/dev/null 2>&1; then
    echo "Git not found. Installing Git..."
    sudo apt-get update && sudo apt-get install -y git
else
    echo "Git is already installed."
fi

# Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
else
    echo "Docker is already installed."
fi

# Docker Compose
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Docker Compose not found. Installing Docker Compose plugin..."
    echo "Importing Caddy GPG key to resolve signature errors..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.gpg > /dev/null
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
else
    echo "Docker Compose is already installed."
fi

# AWS CLI
if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI not found. Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
else
    echo "AWS CLI is already installed."
fi

# ---------------------------
# Override Repository
# ---------------------------
if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists at $REPO_DIR. Overriding with a fresh clone..."
    sudo rm -rf "$REPO_DIR"
fi

echo "Cloning repository from $REPO_URL to $REPO_DIR..."
sudo git clone "$REPO_URL" "$REPO_DIR" || { echo "Failed to clone repository."; exit 1; }

cd "$REPO_DIR" || { echo "Cannot change directory to $REPO_DIR"; exit 1; }

# Ensure the main script is executable
sudo chmod +x n8n-easy-deploy.sh

# ---------------------------
# Create .env if Missing
# ---------------------------
if [ ! -f ".env" ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env || { echo "Failed to create .env file."; exit 1; }
    chmod 600 .env
fi

# ---------------------------
# Edit the .env file interactively using /dev/tty
# ---------------------------
echo "Opening .env file for editing. Please update it with your desired settings, then save and exit the editor."
EDITOR="${EDITOR:-nano}"
$EDITOR .env < /dev/tty

read -rp "Have you saved your changes to .env? (y/N): " CONFIRM < /dev/tty
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Please edit .env and run this script again."
    exit 1
fi

# ---------------------------
# Launch the Main Interactive GUI
# ---------------------------
echo "Launching n8n Easy Deploy interactive menu..."
exec "$REPO_DIR/n8n-easy-deploy.sh"
