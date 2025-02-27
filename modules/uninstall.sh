#!/usr/bin/env bash
# modules/uninstall.sh
# Functions to cleanly uninstall n8n Easy Deploy and remove related resources.

uninstall_n8n_easy_deploy() {
  log "Uninstalling n8n Easy Deploy..."

  # Stop and remove Docker containers, networks, and volumes from the main stack
  docker compose -f "$COMPOSE_FILE" down -v || { log "Failed to stop containers."; exit 1; }

  # If using Caddy via docker-compose.caddy.yml, bring it down as well.
  if [ -f "$CONFIG_DIR/docker-compose.caddy.yml" ]; then
    docker compose -f "$CONFIG_DIR/docker-compose.caddy.yml" down -v
  fi

  # Optionally disable and remove the persistent auto-update service
  if [ -f "$SERVICE_FILE" ]; then
    sudo systemctl stop n8n-easy-deploy-autoupdate.service
    sudo systemctl disable n8n-easy-deploy-autoupdate.service
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
  fi

  # Remove the repository directory
  log "Removing repository directory $CONFIG_DIR..."
  sudo rm -rf "$CONFIG_DIR"

  log "n8n Easy Deploy has been uninstalled."
}
