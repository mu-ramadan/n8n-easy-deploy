#!/usr/bin/env bash
# modules/check.sh
# Functions to diagnose and repair common issues.

check_and_repair() {
  log "Starting check and repair process..."
  
  # 1. .env File Check & Permissions
  if [ ! -f "$ENV_FILE" ]; then
    log "Error: .env file not found in $CONFIG_DIR."
  else
    log ".env file exists."
    local perms
    perms=$(stat -c "%a" "$ENV_FILE")
    if [ "$perms" -ne 600 ]; then
      log "Incorrect permissions on .env file ($perms). Fixing to 600..."
      chmod 600 "$ENV_FILE" && log ".env permissions updated to 600."
    else
      log ".env permissions are correct."
    fi
  fi
  
  # 2. Docker Check
  if ! docker info >/dev/null 2>&1; then
    log "Docker is not running. Attempting to start Docker..."
    sudo systemctl start docker && log "Docker started."
  else
    log "Docker is running."
  fi
  
  # 3. n8n Container Check
  if ! docker compose -f "$COMPOSE_FILE" ps | grep -q n8n; then
    log "n8n container is not running. Attempting to start containers..."
    docker compose -f "$COMPOSE_FILE" up -d && log "Containers started."
  else
    log "n8n container is running."
  fi
  
  # 4. Caddy Check (if DOMAIN_NAME is set)
  local DOMAIN
  DOMAIN=$(grep '^DOMAIN_NAME=' "$ENV_FILE" | cut -d= -f2 || echo "")
  if [ -n "$DOMAIN" ]; then
    if systemctl is-active --quiet caddy; then
      log "Caddy is active."
      if [ ! -f "$CONFIG_DIR/Caddyfile" ]; then
        log "Caddyfile is missing. Reconfiguring..."
        configure_domain_ssl
      else
        log "Caddyfile exists."
      fi
    else
      log "Warning: Caddy is not active. Please ensure Caddy is installed and running."
    fi
  else
    log "No DOMAIN_NAME defined. Skipping Caddy checks."
  fi
  
  # 5. Persistent Auto-Update Status Check
  local auto_status
  auto_status=$( [ -f "$CONFIG_DIR/auto_update_status.txt" ] && cat "$CONFIG_DIR/auto_update_status.txt" || echo "disabled" )
  log "Persistent auto-update service status: $auto_status."
  
  # 6. AWS S3 Connectivity Check
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$ENV_FILE" | cut -d= -f2)
  if [ -n "$AWS_BUCKET" ]; then
    log "Checking AWS S3 connectivity for bucket: $AWS_BUCKET..."
    if aws s3 ls "s3://$AWS_BUCKET/n8n-backups/" >/dev/null 2>&1; then
      log "AWS S3 connectivity is OK."
    else
      log "Warning: Unable to access AWS S3 bucket $AWS_BUCKET. Check AWS configuration."
    fi
  fi
  
  # 7. AWS Credentials Check
  check_aws_credentials
  
  log "Check and repair process completed."
}
