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
# Check dependencies and install if missing.
#######################################
check_dependencies() {
  log "Checking dependencies..."
  for cmd in docker git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log "Error: $cmd is required but not installed. Please install $cmd and re-run this script."
      exit 1
    fi
  done

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

  if ! command -v caddy >/dev/null 2>&1; then
    log "Caddy not found. Installing Caddy..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo apt-key add -
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy -y
  fi

  log "All dependencies are present."
}

#######################################
# Generate Caddyfile Configuration.
#######################################
generate_caddyfile() {
    local caddy_template="$BASE_DIR/config/Caddyfile.template"
    local caddyfile="$BASE_DIR/config/Caddyfile"
    if [ ! -f "$caddy_template" ]; then
        log "Caddyfile template not found: $caddy_template"
        return 1
    fi
    sed -e "s|{{ .LETSENCRYPT_EMAIL }}|$LETSENCRYPT_EMAIL|g" \
        -e "s|{{ .DOMAIN_NAME }}|$DOMAIN_NAME|g" \
        -e "s|{{ .N8N_PORT }}|$N8N_PORT|g" \
        "$caddy_template" > "$caddyfile"
    log "Caddyfile generated at $caddyfile"
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
  # Generate Caddyfile from template
  generate_caddyfile
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
  generate_caddyfile
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
    echo "============================================"
    echo "          n8n Easy Deploy"
    echo "============================================"
    echo ""
    echo "Welcome to n8n Easy Deploy!"
    echo "Deploy, update, backup, and restore your self-hosted n8n instance"
    echo "with ease. Ensure you have updated 'config/.env' with your desired settings,"
    echo "including DOMAIN_NAME and LETSENCRYPT_EMAIL for auto SSL via Caddy."
    echo ""
    echo "--------------------------------------------"
    echo "Menu Options:"
    echo "1. Full Deployment"
    echo "2. Update Instance"
    echo "3. Create Backup (DB & Config)"
    echo "4. Restore Backup (DB & Config)"
    echo "5. Check and Repair"
    echo "7. Backup Workflows & Credentials"
    echo "8. Restore Workflows & Credentials"
    echo "6. Exit"
    echo "--------------------------------------------"
    read -rp "Choose an option (1-8): " choice
    case $choice in
      1) deploy_blue_green ;;
      2) update_instance ;;
      3) backup ;;
      4) restore ;;
      5) check_dependencies && log "System check completed." ;;  # placeholder for additional checks
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
   deploy     : Full deployment (initialize config, start services, auto-configure reverse proxy and SSL)
   update     : Update instance (manual update or toggle persistent auto-update)
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
