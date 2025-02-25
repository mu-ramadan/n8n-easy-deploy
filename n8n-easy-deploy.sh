#!/usr/bin/env bash
# n8n Easy Deploy – A Simple and Secure Deployment GUI for n8n
#
# After cloning this repository, copy .env.example to .env and edit it with your desired settings,
# including USER_EMAIL for auto SSL renewal and AWS credentials if needed.
#
# This script launches an interactive GUI to deploy, update, backup, restore, diagnose/repair,
# and secure/harden your n8n instance.
#
# Prerequisites:
#   - Docker, Docker Compose, and AWS CLI must be installed.
#   - Caddy must be installed (or use docker-compose.caddy.yml) for auto SSL.
#   - Sudo privileges are required for system configuration changes.
#
# It is recommended to run this script through ShellCheck to catch subtle shell issues.

set -Eeuo pipefail

# Global configuration variables
# Use the repository directory as the configuration directory
CONFIG_DIR="$(dirname "$0")"
ENV_FILE="$CONFIG_DIR/.env"
ENV_TEMPLATE="$CONFIG_DIR/.env.example"
BACKUP_DIR="$CONFIG_DIR/backups"
COMPOSE_FILE="$CONFIG_DIR/docker-compose.yml"
LOG_FILE="$CONFIG_DIR/n8n-ctl.log"
RETENTION_COUNT=10

# Source modular scripts
source "$CONFIG_DIR/modules/common.sh"
source "$CONFIG_DIR/modules/config.sh"
source "$CONFIG_DIR/modules/deploy.sh"
source "$CONFIG_DIR/modules/update.sh"
source "$CONFIG_DIR/modules/backup.sh"
source "$CONFIG_DIR/modules/restore.sh"
source "$CONFIG_DIR/modules/check.sh"
source "$CONFIG_DIR/modules/caddy.sh"
source "$CONFIG_DIR/modules/aws.sh"
source "$CONFIG_DIR/modules/security.sh"

#######################################
# Interactive Menu for Operations.
#######################################
show_menu() {
  while true; do
    clear
    echo -e "\n▓ n8n Easy Deploy ▓"
    echo "IMPORTANT: Please ensure you have edited $ENV_FILE with your desired settings."
    echo "1. Full Deployment"
    echo "2. Update Instance"
    echo "3. Create Backup"
    echo "4. Restore Backup"
    echo "5. Check and Repair"
    echo "6. Secure and Harden Server"
    echo "7. Exit"
    read -rp "Choose an option (1-7): " choice
    case $choice in
      1) deploy ;;
      2) update_instance ;;
      3) backup ;;
      4) restore ;;
      5) check_and_repair ;;
      6) secure_server ;;
      7) log "Exiting n8n Easy Deploy." && exit 0 ;;
      *) echo "Invalid option. Try again." && sleep 2 ;;
    esac
  done
}

main() {
  init_config
  show_menu
}

main
