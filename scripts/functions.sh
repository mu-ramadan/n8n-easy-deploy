#!/usr/bin/env bash
set -Eeuo pipefail

# Determine directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$BASE_DIR/config"
BACKUP_DIR="$BASE_DIR/backups"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/n8n-ctl.log"

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR"

# Load environment variables from .env file
if [ -f "$CONFIG_DIR/.env" ]; then
    set -a
    source "$CONFIG_DIR/.env"
    set +a
else
    echo ".env file not found in $CONFIG_DIR. Please create one based on .env.example."
    exit 1
fi

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
  exit "$exit_code"
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
# Initialize configuration.
#######################################
init_config() {
  log "Initializing configuration..."
  if [ ! -f "$CONFIG_DIR/.env" ]; then
    if [ -f "$CONFIG_DIR/.env.example" ]; then
      cp "$CONFIG_DIR/.env.example" "$CONFIG_DIR/.env"
      chmod 600 "$CONFIG_DIR/.env"
      log "Copied .env.example to .env. Please update configuration."
    else
      log "Error: .env or .env.example not found in $CONFIG_DIR."
      exit 1
    fi
  fi
  # Copy docker-compose.yml if missing
  if [ ! -f "$CONFIG_DIR/docker-compose.yml" ]; then
    log "Generating docker-compose.yml from template..."
    cp "$BASE_DIR/config/docker-compose.yml" "$CONFIG_DIR/docker-compose.yml"
  fi
}

#######################################
# Generate Traefik configuration.
#######################################
configure_traefik() {
  log "Configuring Traefik..."
  if [ -z "${DOMAIN_NAME:-}" ]; then
    log "No DOMAIN_NAME specified. Skipping Traefik configuration."
    return
  fi
  local traefik_config="/etc/traefik/dynamic/n8n.yaml"
  if [ ! -d "/etc/traefik/dynamic" ]; then
    log "Creating /etc/traefik/dynamic directory..."
    sudo mkdir -p /etc/traefik/dynamic
  fi
  if [ -n "${SSL_CERT:-}" ] && [ -n "${SSL_KEY:-}" ]; then
    sed -e "s|{{ .SSL_CERT }}|$SSL_CERT|g" -e "s|{{ .SSL_KEY }}|$SSL_KEY|g" \
        -e "s|{{ .DOMAIN_NAME }}|$DOMAIN_NAME|g" -e "s|{{ .N8N_PORT }}|$N8N_PORT|g" \
        "$BASE_DIR/config/traefik/n8n.yaml.template" > /tmp/n8n.yaml
  else
    sed -e "s|{{ .SSL_CERT }}||g" -e "s|{{ .SSL_KEY }}||g" \
        -e "s|{{ .DOMAIN_NAME }}|$DOMAIN_NAME|g" -e "s|{{ .N8N_PORT }}|$N8N_PORT|g" \
        "$BASE_DIR/config/traefik/n8n.yaml.template" > /tmp/n8n.yaml
  fi
  sudo mv /tmp/n8n.yaml "$traefik_config"
  log "Reloading Traefik..."
  sudo systemctl reload traefik
  log "Traefik configuration applied."
}

#######################################
# Blue-Green Deployment Stub.
#######################################
deploy_blue_green() {
  log "Starting blue-green deployment..."
  local ACTIVE_MARKER="$BASE_DIR/active_service.txt"
  local ACTIVE INACTIVE
  if [ -f "$ACTIVE_MARKER" ] && grep -q "blue" "$ACTIVE_MARKER"; then
    ACTIVE="blue"
    INACTIVE="green"
  else
    ACTIVE="green"
    INACTIVE="blue"
  fi
  log "Active service: $ACTIVE. Deploying new version as $INACTIVE..."
  docker compose -f "$CONFIG_DIR/docker-compose.yml" up -d --force-recreate
  echo "$INACTIVE" > "$ACTIVE_MARKER"
  log "Blue-green deployment completed."
}

#######################################
# Update Instance (manual & auto-update toggle).
#######################################
update_instance() {
  local auto_status_file="$BASE_DIR/auto_update_status.txt"
  local status
  if [ -f "$auto_status_file" ]; then
    status=$(cat "$auto_status_file")
  else
    status="disabled"
  fi
  if [ "$status" = "enabled" ]; then
    echo "Auto update is ENABLED."
    echo "1. Trigger manual update"
    echo "2. Disable auto update"
    echo "3. Return"
    read -rp "Choose (1-3): " choice
    case $choice in
      1) log "Triggering manual update..."; deploy_blue_green ;;
      2) disable_auto_update ;;
      3) return ;;
      *) echo "Invalid option." && sleep 2 ;;
    esac
  else
    echo "Auto update is DISABLED."
    echo "1. Trigger manual update"
    echo "2. Enable auto update (persistent)"
    echo "3. Return"
    read -rp "Choose (1-3): " choice
    case $choice in
      1) log "Triggering manual update..."; deploy_blue_green ;;
      2) setup_auto_update ;;
      3) return ;;
      *) echo "Invalid option." && sleep 2 ;;
    esac
  fi
  configure_traefik
}

#######################################
# Auto Update Service Management.
#######################################
setup_auto_update() {
  local script_path
  script_path=$(readlink -f "$0")
  local service_file="/etc/systemd/system/n8n-easy-deploy-autoupdate.service"
  log "Setting up persistent auto update service..."
  sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=n8n Easy Deploy Auto Update Service
After=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/env bash -c "$script_path update"
Restart=always
User=$USER
WorkingDirectory=$BASE_DIR

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable n8n-easy-deploy-autoupdate.service
  sudo systemctl start n8n-easy-deploy-autoupdate.service
  echo "enabled" > "$BASE_DIR/auto_update_status.txt"
  log "Auto update service enabled."
}

disable_auto_update() {
  local service_file="/etc/systemd/system/n8n-easy-deploy-autoupdate.service"
  log "Disabling auto update service..."
  sudo systemctl stop n8n-easy-deploy-autoupdate.service
  sudo systemctl disable n8n-easy-deploy-autoupdate.service
  sudo rm -f "$service_file"
  sudo systemctl daemon-reload
  echo "disabled" > "$BASE_DIR/auto_update_status.txt"
  log "Auto update service disabled."
}

#######################################
# Backup Database & Configuration.
#######################################
backup() {
  check_dependencies
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  local BACKUP_FILE="$BACKUP_DIR/n8n-backup-$TIMESTAMP.tar.gz"
  log "Creating backup at $BACKUP_FILE..."
  docker compose -f "$CONFIG_DIR/docker-compose.yml" exec -T postgres pg_dumpall -U "$DB_USER" > "$BACKUP_DIR/db-backup-$TIMESTAMP.sql"
  tar czf "$BACKUP_FILE" -C "$BASE_DIR" ".env" "docker-compose.yml" "db-backup-$TIMESTAMP.sql" >/dev/null 2>&1
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$CONFIG_DIR/.env" | cut -d= -f2)
  if [ -n "$AWS_BUCKET" ]; then
    log "Uploading backup to s3://$AWS_BUCKET/n8n-backups/ ..."
    aws s3 cp "$BACKUP_FILE" "s3://$AWS_BUCKET/n8n-backups/"
    log "Backup uploaded: s3://$AWS_BUCKET/n8n-backups/$(basename "$BACKUP_FILE")"
  else
    log "AWS_BUCKET not set; backup stored locally."
  fi
  rm -f "$BACKUP_DIR/db-backup-$TIMESTAMP.sql"
  log "Backup completed."
  sleep 3
}

#######################################
# Restore Database & Configuration.
#######################################
restore() {
  check_dependencies
  log "Listing available backups:"
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$CONFIG_DIR/.env" | cut -d= -f2)
  if [ -n "$AWS_BUCKET" ]; then
    aws s3 ls "s3://$AWS_BUCKET/n8n-backups/" | awk '{print $4}'
  else
    ls -1 "$BACKUP_DIR"/n8n-backup-*.tar.gz 2>/dev/null || true
  fi
  read -rp "Enter backup filename to restore: " backup_file
  log "Restoring backup $backup_file..."
  if [ -n "$AWS_BUCKET" ]; then
    aws s3 cp "s3://$AWS_BUCKET/n8n-backups/$backup_file" "$BACKUP_DIR/"
  fi
  tar xzf "$BACKUP_DIR/$backup_file" -C "$BASE_DIR"
  local SQL_DUMP
  SQL_DUMP=$(tar tzf "$BACKUP_DIR/$backup_file" | grep 'db-backup-.*\.sql' || true)
  if [ -n "$SQL_DUMP" ]; then
    log "Restoring database from $(basename "$SQL_DUMP")..."
    docker compose -f "$CONFIG_DIR/docker-compose.yml" exec -T postgres psql -U "$DB_USER" < "$BASE_DIR/$(basename "$SQL_DUMP")"
  fi
  docker compose -f "$CONFIG_DIR/docker-compose.yml" up -d
  log "Restore completed."
  sleep 3
}

#######################################
# Backup n8n Workflows & Credentials.
#######################################
backup_wc() {
  check_dependencies
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  local workflows_file="$BASE_DIR/workflows-backup-$TIMESTAMP.json"
  local credentials_file="$BASE_DIR/credentials-backup-$TIMESTAMP.json"
  local BACKUP_FILE="$BACKUP_DIR/n8n-wc-backup-$TIMESTAMP.tar.gz"
  log "Starting backup of workflows and credentials..."
  log "Exporting workflows to $workflows_file..."
  n8n export:workflow --all --output="$workflows_file"
  log "Exporting credentials to $credentials_file..."
  n8n export:credentials --all --output="$credentials_file"
  tar czf "$BACKUP_FILE" -C "$BASE_DIR" "$(basename "$workflows_file")" "$(basename "$credentials_file")" >/dev/null 2>&1
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$CONFIG_DIR/.env" | cut -d= -f2)
  if [ -n "$AWS_BUCKET" ]; then
    log "Uploading workflows & credentials backup to s3://$AWS_BUCKET/n8n-wc-backups/ ..."
    aws s3 cp "$BACKUP_FILE" "s3://$AWS_BUCKET/n8n-wc-backups/"
    log "Backup uploaded: s3://$AWS_BUCKET/n8n-wc-backups/$(basename "$BACKUP_FILE")"
  else
    log "AWS_BUCKET not set; backup stored locally."
  fi
  rm -f "$workflows_file" "$credentials_file"
  log "Workflows & credentials backup completed."
  sleep 3
}

#######################################
# Restore n8n Workflows & Credentials.
#######################################
restore_wc() {
  check_dependencies
  log "Listing available workflows & credentials backups:"
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$CONFIG_DIR/.env" | cut -d= -f2)
  if [ -n "$AWS_BUCKET" ]; then
    aws s3 ls "s3://$AWS_BUCKET/n8n-wc-backups/" | awk '{print $4}'
  else
    ls -1 "$BACKUP_DIR"/n8n-wc-backup-*.tar.gz 2>/dev/null || true
  fi
  read -rp "Enter backup filename to restore (e.g., n8n-wc-backup-YYYYMMDD-HHMMSS.tar.gz): " backup_file
  log "Restoring workflows & credentials backup $backup_file..."
  if [ -n "$AWS_BUCKET" ]; then
    aws s3 cp "s3://$AWS_BUCKET/n8n-wc-backups/$backup_file" "$BACKUP_DIR/"
  fi
  tar xzf "$BACKUP_DIR/$backup_file" -C "$BASE_DIR"
  for file in $(tar tzf "$BACKUP_DIR/$backup_file"); do
    if [[ "$file" == workflows-backup-*.json ]]; then
      log "Importing workflows from $file..."
      n8n import:workflow --input="$BASE_DIR/$file"
      rm -f "$BASE_DIR/$file"
    elif [[ "$file" == credentials-backup-*.json ]]; then
      log "Importing credentials from $file..."
      n8n import:credentials --input="$BASE_DIR/$file"
      rm -f "$BASE_DIR/$file"
    fi
  done
  log "Workflows & credentials restoration completed."
  sleep 3
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
    echo "3. Create Backup (DB & Config)"
    echo "4. Restore Backup (DB & Config)"
    echo "5. Check and Repair"
    echo "7. Backup Workflows & Credentials"
    echo "8. Restore Workflows & Credentials"
    echo "6. Exit"
    read -rp "Choose an option (1-8): " choice
    case $choice in
      1) deploy_blue_green ;;
      2) update_instance ;;
      3) backup ;;
      4) restore ;;
      5) check_dependencies && log "System check completed." ;;  # placeholder for a more robust check_and_repair function
      7) backup_wc ;;
      8) restore_wc ;;
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
Usage: $(basename "$0") {deploy|update|backup|restore|check|backupwc|restorewc|help}
   deploy     : Full deployment (initialize config, start services, auto-configure domain/SSL)
   update     : Update instance (manual update or toggle persistent auto-update; domain/SSL auto-configured)
   backup     : Backup database & configuration and upload to AWS S3 (if configured)
   restore    : Restore backup from AWS S3 (or local storage)
   check      : Check and repair common issues
   backupwc   : Backup n8n workflows & credentials (and upload to AWS S3 if configured)
   restorewc  : Restore n8n workflows & credentials backup from AWS S3 or local storage
   help       : Display this help message
EOF
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      deploy) deploy_blue_green ;;
      update) update_instance ;;
      backup) backup ;;
      restore) restore ;;
      check) check_dependencies ;;  # or a dedicated check_and_repair function
      backupwc) backup_wc ;;
      restorewc) restore_wc ;;
      help) usage ;;
      *) usage; exit 1 ;;
    esac
  else
    show_menu
  fi
}

# Start the script.
main "$@"
