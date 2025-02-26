#!/usr/bin/env bash
# modules/deploy.sh
# Functions for full deployment and blue-green updates.

deploy() {
  check_dependencies
  init_config
  log "Starting n8n deployment..."
  docker compose -f "$COMPOSE_FILE" up -d
  log "Deployment complete! Access n8n at: http://<YOUR-SERVER-IP>:$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)"
}

deploy_blue_green() {
  log "Starting blue-green deployment stub..."
  local ACTIVE INACTIVE
  local ACTIVE_MARKER="$CONFIG_DIR/active_service.txt"
  if [ -f "$ACTIVE_MARKER" ] && grep -q "blue" "$ACTIVE_MARKER"; then
    ACTIVE="blue"
    INACTIVE="green"
  else
    ACTIVE="green"
    INACTIVE="blue"
  fi
  log "Active service is: $ACTIVE. Deploying new version as $INACTIVE..."
  log "Blue-green deployment stub complete. (Simulating update.)"
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate
}

deploy_local() {
  check_dependencies
  init_config
  log "Starting local n8n deployment (without domain/SSL)..."
  
  # Open the required port in UFW, if installed.
  if command -v ufw >/dev/null 2>&1; then
      local n8n_port
      n8n_port=$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)
      log "Configuring UFW: Allowing TCP traffic on port $n8n_port..."
      sudo ufw allow "$n8n_port"/tcp
  else
      log "UFW not found. Ensure port $(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2) is open."
  fi
  
  docker compose -f "$COMPOSE_FILE" up -d n8n postgres redis
  log "Local deployment complete! Access n8n at: http://<YOUR-SERVER-IP>:$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)"
}
