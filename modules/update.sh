#!/usr/bin/env bash
# modules/update.sh
# Functions for updating the instance and managing persistent auto-update.

persistent_autoupdate_status_file="$CONFIG_DIR/auto_update_status.txt"
SERVICE_FILE="/etc/systemd/system/n8n-easy-deploy-autoupdate.service"

setup_persistent_autoupdate() {
  local script_path
  script_path=$(readlink -f "$0")
  log "Setting up persistent auto update service..."
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=n8n Easy Deploy Auto Update Service
After=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/env bash -c "$(readlink -f "$0") update_instance"
Restart=always
User=$USER
WorkingDirectory=$CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable n8n-easy-deploy-autoupdate.service
  sudo systemctl start n8n-easy-deploy-autoupdate.service
  echo "enabled" > "$persistent_autoupdate_status_file"
  log "Persistent auto update service enabled."
}

disable_persistent_autoupdate() {
  log "Disabling persistent auto update service..."
  sudo systemctl stop n8n-easy-deploy-autoupdate.service
  sudo systemctl disable n8n-easy-deploy-autoupdate.service
  sudo rm -f "$SERVICE_FILE"
  sudo systemctl daemon-reload
  echo "disabled" > "$persistent_autoupdate_status_file"
  log "Persistent auto update service disabled."
}

update_instance() {
  local status
  status=$( [ -f "$persistent_autoupdate_status_file" ] && cat "$persistent_autoupdate_status_file" || echo "disabled" )
  if [ "$status" = "enabled" ]; then
    echo "Auto update is currently ENABLED."
    echo "Options:"
    echo "1. Trigger manual update now"
    echo "2. Disable auto update"
    echo "3. Return to main menu"
    read -rp "Choose an option (1-3): " choice
    case $choice in
      1) log "Triggering manual update (blue-green deployment)..." && deploy_blue_green ;;
      2) disable_persistent_autoupdate ;;
      3) return ;;
      *) echo "Invalid option." && sleep 2 ;;
    esac
  else
    echo "Auto update is currently DISABLED."
    echo "Options:"
    echo "1. Trigger manual update now"
    echo "2. Enable auto update (persistent mode)"
    echo "3. Return to main menu"
    read -rp "Choose an option (1-3): " choice
    case $choice in
      1) log "Triggering manual update (blue-green deployment)..." && deploy_blue_green ;;
      2) setup_persistent_autoupdate ;;
      3) return ;;
      *) echo "Invalid option." && sleep 2 ;;
    esac
  fi
  configure_domain_ssl
}
