#!/usr/bin/env bash
# n8n Easy Deploy – A Simple and Secure Deployment Tool for n8n
#
# This tool simplifies the deployment, updating, backup, and restoration
# of your self-hosted n8n instance. It uses a manual .env template approach
# for configuration and provides modular functions for ease of maintenance.
#
# New features in this version:
#   • Consolidated update functionality (manual update and persistent auto-update)
#   • Automated domain and SSL configuration using Traefik:
#         - If DOMAIN_NAME is defined in .env, a dynamic Traefik configuration is generated.
#         - If SSL_CERT and SSL_KEY are provided, those are used; otherwise, auto-TLS is used.
#   • Check and Repair option to diagnose and fix common issues.
#   • **Backup Version Check and Instance Adjustment:** The backup function records
#         the current n8n version (using n8n --version) into version.txt (included in the backup).
#         During restore, if the backup version does not match the running instance,
#         the user is prompted to update the running instance (by modifying the docker-compose image tag)
#         to match the backup. This allows for a downgrade or upgrade.
#
# Prerequisites:
#   - Docker, Docker Compose, and AWS CLI must be installed.
#   - Traefik must be installed and active for automated domain/SSL configuration.
#   - Sudo privileges are required for actions that write to system directories.
#
# It is recommended to run this script through ShellCheck to catch subtle shell issues.
#
# Usage (command-line):
#   ./n8n-ctl.sh deploy         : Full deployment (initialize config, start services, auto-configure domain/SSL)
#   ./n8n-ctl.sh update         : Update instance (trigger manual update or toggle persistent auto-update)
#   ./n8n-ctl.sh backup         : Create a backup (including n8n version) and upload to AWS S3
#   ./n8n-ctl.sh restore        : Restore backup from AWS S3 (with version compatibility check)
#   ./n8n-ctl.sh check          : Check and repair system issues
#   ./n8n-ctl.sh help           : Display this help message

set -Eeuo pipefail

# Global configuration paths
SCRIPT_NAME=$(basename "$0")
CONFIG_DIR="$HOME/n8n-ctl"
ENV_FILE="$CONFIG_DIR/.env"
ENV_TEMPLATE="$CONFIG_DIR/.env.example"
BACKUP_DIR="$CONFIG_DIR/backups"
COMPOSE_FILE="$CONFIG_DIR/docker-compose.yml"
LOG_FILE="$CONFIG_DIR/n8n-ctl.log"

# Backup retention: keep only the latest 10 backups.
RETENTION_COUNT=10

#######################################
# Logging function with timestamp.
#######################################
log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*" | tee -a "$LOG_FILE"
}

#######################################
# Global error trap.
#######################################
notify_error() {
  local exit_code=$?
  log "ERROR: Command failed (exit code ${exit_code}): ${BASH_COMMAND}"
}
trap notify_error ERR
trap 'log "Interrupted by signal"; exit 130' SIGINT SIGTERM

#######################################
# Check dependencies.
#######################################
check_dependencies() {
  log "Checking dependencies..."
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
  fi
  if ! command -v docker-compose >/dev/null 2>&1; then
    log "Docker Compose not found. Installing Docker Compose plugin..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
  fi
  if ! command -v aws >/dev/null 2>&1; then
    log "AWS CLI not found. Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
  fi
}

#######################################
# Validate required variables in .env.
#######################################
validate_env() {
  local var
  for var in N8N_PORT DB_USER DB_PASS AWS_BUCKET; do
    if ! grep -q "^${var}=" "$ENV_FILE"; then
      log "Error: ${var} not set in $ENV_FILE"
      exit 1
    fi
  done
}

#######################################
# Initialize configuration directories and files.
# Uses .env.example as a template for .env if needed.
#######################################
init_config() {
  log "Initializing configuration..."
  mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_TEMPLATE" ]; then
      cp "$ENV_TEMPLATE" "$ENV_FILE"
      chmod 600 "$ENV_FILE"
      log "No .env file found. Template copied from .env.example to .env."
      log "Please review and update $ENV_FILE with your specific configuration values."
    else
      log "Error: Neither .env nor .env.example exists in $CONFIG_DIR."
      log "Please create a .env file manually based on your n8n configuration requirements."
      exit 1
    fi
  fi
  validate_env
  if [ ! -f "$COMPOSE_FILE" ]; then
    log "Generating docker-compose.yml file..."
    cat <<'EOF' > "$COMPOSE_FILE"
version: '3'

services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "${N8N_PORT}:${N8N_PORT}"
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${DB_HOST}
      - DB_POSTGRESDB_PORT=${DB_PORT}
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASS}
      - DB_POSTGRESDB_DATABASE=${DB_NAME}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${DB_PASS}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - pg_data:/var/lib/postgresql/data

  redis:
    image: redis:7.2-alpine
    command: redis-server --requirepass ${REDIS_PASS}
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - redis_data:/data

volumes:
  pg_data:
  redis_data:
EOF
  fi
}

#######################################
# Traefik Domain & SSL Configuration (Automated).
# If DOMAIN_NAME is defined in .env, this function automatically
# writes a Traefik dynamic configuration file for domain/SSL.
# Uses SSL_CERT and SSL_KEY if provided; otherwise uses auto-TLS with certResolver "myresolver".
#######################################
configure_domain_ssl() {
  local DOMAIN
  DOMAIN=$(grep '^DOMAIN_NAME=' "$ENV_FILE" | cut -d= -f2 || echo "")
  if [ -z "$DOMAIN" ]; then
    log "No DOMAIN_NAME defined in $ENV_FILE. Skipping domain configuration."
    return
  fi
  local N8N_PORT
  N8N_PORT=$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)
  local traefik_config="/etc/traefik/dynamic/n8n.yaml"
  
  # Ensure Traefik dynamic config directory exists.
  if [ ! -d "/etc/traefik/dynamic" ]; then
    log "Creating /etc/traefik/dynamic directory..."
    sudo mkdir -p /etc/traefik/dynamic
  fi
  
  local SSL_CERT SSL_KEY
  SSL_CERT=$(grep '^SSL_CERT=' "$ENV_FILE" | cut -d= -f2 || echo "")
  SSL_KEY=$(grep '^SSL_KEY=' "$ENV_FILE" | cut -d= -f2 || echo "")
  
  if [ -n "$SSL_CERT" ] && [ -n "$SSL_KEY" ]; then
    sudo tee "$traefik_config" > /dev/null <<EOF
tls:
  certificates:
    - certFile: "$SSL_CERT"
      keyFile: "$SSL_KEY"

http:
  routers:
    n8n-router:
      rule: "Host(\`$DOMAIN\`)"
      entryPoints:
        - websecure
      service: n8n-service
      tls: {}
  services:
    n8n-service:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:$N8N_PORT"
EOF
    log "Traefik configuration updated to use custom SSL certificate for domain: $DOMAIN."
  else
    sudo tee "$traefik_config" > /dev/null <<EOF
http:
  routers:
    n8n-router:
      rule: "Host(\`$DOMAIN\`)"
      entryPoints:
        - websecure
      service: n8n-service
      tls:
        certResolver: myresolver
  services:
    n8n-service:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:$N8N_PORT"
EOF
    log "Traefik configuration updated for domain: $DOMAIN using auto-TLS (Let's Encrypt)."
  fi
  log "Reloading Traefik..."
  sudo systemctl reload traefik
  log "Domain and SSL configuration applied via Traefik."
}

#######################################
# Blue-Green Deployment Stub (Zero Downtime Upgrade).
# This stub simulates a blue-green deployment strategy.
# Extend with full logic as needed.
#######################################
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
  # Stub: Extend for full blue-green deployment logic.
  log "Blue-green deployment stub complete. (Simulating update.)"
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate
}

#######################################
# Backup n8n: Record n8n version, dump database, and archive configuration.
# The current n8n version (from n8n --version) is saved in version.txt and included in the backup.
#######################################
backup() {
  check_dependencies
  local current_version
  current_version=$(docker compose -f "$COMPOSE_FILE" exec -T n8n n8n --version 2>/dev/null | tr -d '\r')
  echo "$current_version" > "$CONFIG_DIR/version.txt"
  log "Recorded n8n version: $current_version in version.txt."
  
  local TIMESTAMP
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  local BACKUP_FILE="$BACKUP_DIR/n8n-backup-$TIMESTAMP.tar.gz"
  log "Creating backup at $BACKUP_FILE..."
  
  local DB_USER
  DB_USER=$(grep '^DB_USER=' "$ENV_FILE" | cut -d= -f2)
  docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dumpall -U "$DB_USER" > "$BACKUP_DIR/db-backup-$TIMESTAMP.sql"
  tar czf "$BACKUP_FILE" -C "$CONFIG_DIR" "$(basename "$ENV_FILE")" "$(basename "$COMPOSE_FILE")" "version.txt" "db-backup-$TIMESTAMP.sql" >/dev/null 2>&1
  
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$ENV_FILE" | cut -d= -f2)
  log "Uploading backup to s3://$AWS_BUCKET/n8n-backups/ ..."
  aws s3 cp "$BACKUP_FILE" "s3://$AWS_BUCKET/n8n-backups/"
  log "Backup complete: s3://$AWS_BUCKET/n8n-backups/$(basename "$BACKUP_FILE")"
  cleanup_old_backups
  sleep 3
}

#######################################
# Restore backup: Restore from AWS S3 and handle version differences.
# If the backup version differs from the current n8n version,
# prompt the user to update the running instance to the backup version.
#######################################
restore() {
  check_dependencies
  log "Listing available backups from S3:"
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$ENV_FILE" | cut -d= -f2)
  aws s3 ls "s3://$AWS_BUCKET/n8n-backups/" | awk '{print $4}'
  read -rp "Enter backup filename to restore: " backup_file
  log "Restoring backup $backup_file..."
  docker compose -f "$COMPOSE_FILE" down
  aws s3 cp "s3://$AWS_BUCKET/n8n-backups/$backup_file" "$BACKUP_DIR/"
  tar xzf "$BACKUP_DIR/$backup_file" -C "$CONFIG_DIR"
  
  # Check version compatibility
  if [ -f "$CONFIG_DIR/version.txt" ]; then
    local backup_version current_version
    backup_version=$(cat "$CONFIG_DIR/version.txt" | tr -d '\r')
    current_version=$(docker compose -f "$COMPOSE_FILE" exec -T n8n n8n --version 2>/dev/null | tr -d '\r')
    if [ "$backup_version" != "$current_version" ]; then
      log "Version mismatch: Backup version is $backup_version but current n8n version is $current_version."
      read -rp "Do you want to update your n8n instance to version $backup_version? (y/N): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "Updating docker-compose file to use n8nio/n8n:${backup_version}..."
        sudo sed -i "s|n8nio/n8n:.*|n8nio/n8n:${backup_version}|" "$COMPOSE_FILE"
        log "Pulling n8n image version ${backup_version}..."
        docker compose -f "$COMPOSE_FILE" pull n8n
        log "Recreating n8n container with version ${backup_version}..."
        docker compose -f "$COMPOSE_FILE" up -d --force-recreate
        current_version=$(docker compose -f "$COMPOSE_FILE" exec -T n8n n8n --version 2>/dev/null | tr -d '\r')
        if [ "$backup_version" != "$current_version" ]; then
          log "Error: Failed to update n8n to version $backup_version. Current version is $current_version."
          exit 1
        else
          log "Successfully updated n8n to version $backup_version."
        fi
      else
        log "Restore aborted due to version mismatch."
        exit 1
      fi
    else
      log "Version check passed: Both backup and current n8n version are $current_version."
    fi
  else
    log "Warning: version.txt not found in backup. Proceeding without version check."
  fi
  
  local SQL_DUMP
  SQL_DUMP=$(tar tzf "$BACKUP_DIR/$backup_file" | grep 'db-backup-.*\.sql' || true)
  if [ -n "$SQL_DUMP" ]; then
    local DB_USER
    DB_USER=$(grep '^DB_USER=' "$ENV_FILE" | cut -d= -f2)
    log "Restoring database from $(basename "$SQL_DUMP")..."
    docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" < "$BACKUP_DIR/$(basename "$SQL_DUMP")"
  fi
  docker compose -f "$COMPOSE_FILE" up -d
  log "Restore completed successfully."
  sleep 3
}

#######################################
# Check and Repair: Diagnose common issues and attempt repairs.
#######################################
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
  
  # 4. Traefik Check (if DOMAIN_NAME is set)
  local DOMAIN
  DOMAIN=$(grep '^DOMAIN_NAME=' "$ENV_FILE" | cut -d= -f2 || echo "")
  if [ -n "$DOMAIN" ]; then
    if systemctl is-active --quiet traefik; then
      log "Traefik is active."
      if [ ! -f "/etc/traefik/dynamic/n8n.yaml" ]; then
        log "Traefik dynamic config for n8n is missing. Reconfiguring..."
        configure_domain_ssl
      else
        log "Traefik dynamic configuration file exists."
      fi
    else
      log "Warning: Traefik is not active. Please ensure Traefik is installed and running."
    fi
  else
    log "No DOMAIN_NAME defined. Skipping Traefik checks."
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
  
  log "Check and repair process completed."
}

#######################################
# Update Instance: Consolidated update functionality.
# Allows the user to trigger a manual update or toggle persistent auto-update.
# After update, domain/SSL is auto-configured.
#######################################
update_instance() {
  local status
  status=$( [ -f "$CONFIG_DIR/auto_update_status.txt" ] && cat "$CONFIG_DIR/auto_update_status.txt" || echo "disabled" )
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
  # Automatically update domain/SSL configuration after update.
  configure_domain_ssl
}

#######################################
# Persistent Auto Update Service Management via systemd.
#######################################
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
ExecStart=/usr/bin/env bash -c "$script_path update_instance"
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

#######################################
# Auto Update Mode: Periodically check for updates.
# Uses UPDATE_INTERVAL from .env (in seconds; default: 86400 seconds).
#######################################
auto_update() {
  local interval=${UPDATE_INTERVAL:-86400}
  log "Starting auto update mode. Update interval: ${interval} seconds."
  while true; do
    log "Auto update: Initiating update..."
    deploy_blue_green
    log "Auto update: Update complete. Waiting for ${interval} seconds until next update..."
    sleep "${interval}"
    configure_domain_ssl
  done
}

#######################################
# Interactive Menu for Operations.
#######################################
show_menu() {
  while true; do
    clear
    echo -e "\n▓ n8n Easy Deploy ▓"
    echo "1. Full Deployment"
    echo "2. Update Instance"
    echo "3. Create Backup"
    echo "4. Restore Backup"
    echo "5. Check and Repair"
    echo "6. Exit"
    read -rp "Choose an option (1-6): " choice
    case $choice in
      1) deploy ;;
      2) update_instance ;;
      3) backup ;;
      4) restore ;;
      5) check_and_repair ;;
      6) log "Exiting n8n Easy Deploy." && exit 0 ;;
      *) echo "Invalid option. Try again." && sleep 2 ;;
    esac
  done
}

#######################################
# Command-Line Parser for Non-Interactive Mode.
#######################################
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME {deploy|update|backup|restore|check|help}
   deploy : Full deployment (initialize config, start services, auto-configure domain/SSL)
   update : Update instance (manual update or toggle persistent auto-update; domain/SSL auto-configured)
   backup : Create a backup (includes n8n version) and upload to AWS S3
   restore: Restore backup from AWS S3 (version check and instance version adjustment)
   check  : Check and repair common issues
   help   : Display this help message
EOF
}

#######################################
# Main Entry Point: Process Command-Line Arguments.
#######################################
main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      deploy) deploy ;;
      update) update_instance ;;
      backup) backup ;;
      restore) restore ;;
      check) check_and_repair ;;
      help) usage ;;
      *) usage; exit 1 ;;
    esac
  else
    show_menu
  fi
}

# Start the control script.
main "$@"
