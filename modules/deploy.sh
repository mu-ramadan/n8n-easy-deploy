#!/usr/bin/env bash
# modules/deploy.sh
# Functions for full deployment and blue-green updates.

deploy() {
  check_dependencies
  init_config
  log "Starting n8n deployment..."
  docker compose -f "$COMPOSE_FILE" up -d
  log "Deployment complete! Access n8n at: http://localhost:$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)"
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
