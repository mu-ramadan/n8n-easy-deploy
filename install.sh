#!/usr/bin/env bash
# install.sh
#
# This script automates the complete installation of n8n Easy Deploy.
# It will:
# 1. Check for and install all required software (Docker, Docker Compose, AWS CLI, Git).
# 2. Clone the repository from GitHub (if not already present) into /opt/n8n-easy-deploy.
# 3. Set proper permissions on the main script.
# 4. Create a .env file from .env.example if it doesn't exist.
# 5. Open the .env file for editing (using /dev/tty for interactive input).
# 6. Launch the main interactive GUI.
#
# Usage: Run via curl as:
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
# Clone the Repository
# ---------------------------
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning repository from $REPO_URL to $REPO_DIR..."
    sudo git clone "$REPO_URL" "$REPO_DIR" || { echo "Failed to clone repository."; exit 1; }
else
    echo "Repository already exists at $REPO_DIR."
fi

cd "$REPO_DIR" || { echo "Cannot change directory to $REPO_DIR"; exit 1; }

# Ensure the main script is executable
sudo chmod +x n8n-easy-deploy.sh

# ----------
