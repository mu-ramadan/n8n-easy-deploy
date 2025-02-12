#!/usr/bin/env bash
# install.sh - Automated installer for n8n Easy Deploy
#
# This installer will:
#   - Check for and install required packages: Git, Docker, Docker Compose,
#     AWS CLI, Caddy, and unzip.
#   - Clone (or update) the repository into a folder named "n8n-easy-deploy"
#     in the current directory.
#   - Set necessary permissions and create required directories.
#   - Ensure a configuration file exists.
#   - Optionally launch the main control script.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/mu-ramadan/n8n-easy-deploy/refs/heads/main/install.sh | sudo bash

# Ensure the script is running under Bash
if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script must be run with Bash. Re-executing using bash..."
  exec /usr/bin/env bash "$0" "$@"
fi

# Exit immediately on error, treat unset variables as errors, and ensure pipeline errors are caught.
set -Eeuo pipefail
IFS=$'\n\t'

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Please run with sudo."
  exit 1
fi

# ------------------------------------------------------------------------------
# Logging and Command Runner
# ------------------------------------------------------------------------------
LOG_FILE="/tmp/n8n-easy-deploy-install.log"
: > "$LOG_FILE"  # Clear (or create) the log file

# run_step prints a brief progress message, runs the given command (using eval),
# and prints "Done" if successful or "Failed" if not.
run_step() {
  local description="$1"
  local command="$2"
  echo -n "$description... "
  if eval "$command" >> "$LOG_FILE" 2>&1; then
    echo "Done."
  else
    echo "Failed. Please check the log file at $LOG_FILE for details."
    exit 1
  fi
}

# wait_for_apt_lock waits for any active apt/dpkg process to release the lock.
wait_for_apt_lock() {
  local lock_file="/var/lib/dpkg/lock-frontend"
  echo -n "Waiting for apt/dpkg lock to be released... "
  while fuser "$lock_file" >/dev/null 2>&1; do
    sleep 5
  done
  echo "Done."
}

# ------------------------------------------------------------------------------
# Display Header
# ------------------------------------------------------------------------------
echo "============================================"
echo "          n8n Easy Deploy Installer"
echo "============================================"
echo ""

# ------------------------------------------------------------------------------
# Check for Git
# ------------------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  echo "Git is not installed. Please install Git and re-run this script."
  exit 1
fi

# ------------------------------------------------------------------------------
# Install Docker (if missing)
# ------------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  run_step "Installing Docker" "curl -fsSL https://get.docker.com | sh"
  # Add the non-root user (if available) to the docker group.
  user_to_add="${SUDO_USER:-$USER}"
  run_step "Adding user '$user_to_add' to Docker group" "usermod -aG docker $user_to_add"
fi

# ------------------------------------------------------------------------------
# Install Docker Compose Plugin (if missing)
# ------------------------------------------------------------------------------
if ! command -v docker-compose >/dev/null 2>&1; then
  wait_for_apt_lock
  run_step "Installing Docker Compose plugin" "apt-get update -qq && apt-get install -y docker-compose-plugin"
fi

# ------------------------------------------------------------------------------
# Install unzip (if missing; needed for AWS CLI)
# ------------------------------------------------------------------------------
if ! command -v unzip >/dev/null 2>&1; then
  wait_for_apt_lock
  run_step "Installing unzip" "apt-get update -qq && apt-get install -y unzip"
fi

# ------------------------------------------------------------------------------
# Install AWS CLI (if missing)
# ------------------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  run_step "Installing AWS CLI" "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws"
fi

# ------------------------------------------------------------------------------
# Install Caddy (if missing)
# ------------------------------------------------------------------------------
if ! command -v caddy >/dev/null 2>&1; then
  wait_for_apt_lock
  run_step "Installing Caddy dependencies" "apt-get update -qq && apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg"
  run_step "Adding Caddy GPG key" "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor > /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
  run_step "Adding Caddy repository" "echo 'deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main' > /etc/apt/sources.list.d/caddy-stable.list"
  wait_for_apt_lock
  run_step "Installing Caddy" "apt-get update -qq && apt-get install -y caddy"
fi

echo ""
echo "All required packages are installed."
echo ""

# ------------------------------------------------------------------------------
# Clone or Update Repository
# ------------------------------------------------------------------------------
REPO_URL="https://github.com/mu-ramadan/n8n-easy-deploy.git"
TARGET_DIR="$PWD/n8n-easy-deploy"

if [ -d "$TARGET_DIR" ]; then
  echo -n "Repository already exists in $TARGET_DIR. Do you want to update it? (y/n): "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    run_step "Updating repository" "cd \"$TARGET_DIR\" && git pull"
  else
    echo "Skipping repository update."
  fi
else
  run_step "Cloning repository" "git clone \"$REPO_URL\" \"$TARGET_DIR\""
fi

# ------------------------------------------------------------------------------
# Set Permissions and Create Directories
# ------------------------------------------------------------------------------
run_step "Setting file permissions for control script" "chmod +x \"$TARGET_DIR/scripts/n8n-ctl.sh\""
run_step "Creating backups and logs directories" "mkdir -p \"$TARGET_DIR/backups\" \"$TARGET_DIR/logs\""

# ------------------------------------------------------------------------------
# Ensure Configuration File Exists
# ------------------------------------------------------------------------------
CONFIG_FILE="$TARGET_DIR/config/.env"
if [ ! -f "$CONFIG_FILE" ]; then
  run_step "Creating configuration file from sample" "cp \"$TARGET_DIR/config/.env.example\" \"$CONFIG_FILE\""
  echo "Please review and update the configuration file ($CONFIG_FILE) with your settings (e.g., DOMAIN_NAME and LETSENCRYPT_EMAIL)."
fi

echo ""
echo "============================================"
echo "Installation complete!"
echo "To start n8n Easy Deploy, run the following commands:"
echo "  cd $TARGET_DIR"
echo "  ./scripts/n8n-ctl.sh"
echo "============================================"
echo ""
echo -n "Would you like to launch the n8n Easy Deploy menu now? (y/n): "
read -r launch_choice
if [[ "$launch_choice" =~ ^[Yy]$ ]]; then
  cd "$TARGET_DIR" && ./scripts/n8n-ctl.sh
else
  echo "You can start n8n Easy Deploy later by navigating to $TARGET_DIR and running ./scripts/n8n-ctl.sh"
fi
