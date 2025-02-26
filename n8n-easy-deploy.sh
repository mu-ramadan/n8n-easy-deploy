#!/usr/bin/env bash
# n8n Easy Deploy – A Simple and Secure Deployment GUI for n8n
#
# This script launches an interactive GUI to deploy, update, backup, restore,
# diagnose/repair, secure/harden, or uninstall n8n Easy Deploy.
#
# Prerequisites:
#   - Docker, Docker Compose, AWS CLI, etc. must be installed.
#   - Caddy is used for domain/SSL (skipped in local deployments).
#   - Sudo privileges are required for system configuration changes.
#
# It is recommended to run this script through ShellCheck.

set -Eeuo pipefail

# Global configuration variables (using the repo directory as CONFIG_DIR)
CONFIG_DIR="$(dirname "$0")"
ENV_FILE="$CONFIG_DIR/.env"
ENV_TEMPLATE="$CONFIG_DIR/.env.example"
BACKUP_DIR="$CONFIG_DIR/backups"
COMPOSE_FILE="$CONFIG_DIR/docker-compose.yml"
LOG_FILE="$CONFIG_DIR/n8n-ctl.log"
RETENTION_COUNT=10

# Source modular scripts
for module in common.sh config.sh deploy.sh update.sh backup.sh restore.sh check.sh caddy.sh aws.sh security.sh uninstall.sh; do
    if [ -f "$CONFIG_DIR/modules/$module" ]; then
        source "$CONFIG_DIR/modules/$module"
    else
        echo "ERROR: Module $module not found in $CONFIG_DIR/modules/"
        exit 1
    fi
done

#######################################
# Interactive Menu for Operations.
#######################################
show_menu() {
  while true; do
    tput reset
    echo -e "\n▓ n8n Easy Deploy ▓"
    echo "IMPORTANT: Please ensure you have edited $ENV_FILE with your desired settings."
    echo "1. Full Deployment"
    echo "2. Update Instance"
    echo "3. Create Backup"
    echo "4. Restore Backup"
    echo "5. Check and Repair"
    echo "6. Secure and Harden Server"
    echo "7. Local Deployment (No Domain)"
    echo "8. Uninstall n8n Easy Deploy"
    echo "9. Exit"
    read -rp "Choose an option (1-9): " choice </dev/tty

    case "$choice" in
      1) deploy || { log "Deployment failed."; sleep 3; } ;;
      2) update_instance || { log "Update failed."; sleep 3; } ;;
      3) backup || { log "Backup failed."; sleep 3; } ;;
      4) restore || { log "Restore failed."; sleep 3; } ;;
      5) check_and_repair || { log "Check and repair encountered errors."; sleep 3; } ;;
      6) secure_server || { log "Security hardening failed."; sleep 3; } ;;
      7) deploy_local || { log "Local deployment failed."; sleep 3; } ;;
      8)
         log "Uninstalling n8n Easy Deploy..."
         uninstall_n8n_easy_deploy
         exit 0
         ;;
      9) log "Exiting n8n Easy Deploy." && exit 0 ;;
      *) echo "Invalid option. Try again." && sleep 2 ;;
    esac

    echo "Press Enter to return to the menu..." && read -r </dev/tty
  done
}

main() {
  init_config || { echo "Initialization failed. Check log at $LOG_FILE"; exit 1; }
  show_menu
}

main
