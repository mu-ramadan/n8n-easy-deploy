#!/usr/bin/env bash
# modules/restore.sh
# Functions for restoring n8n from backup with version compatibility check and instance adjustment.

restore() {
  check_dependencies
  log "Listing available backups from S3:"
  local AWS_BUCKET
  AWS_BUCKET=$(grep '^AWS_BUCKET=' "$ENV_FILE" | cut -d= -f2)
  aws s3 ls "s3://$AWS_BUCKET/n8n-backups/" | awk '{print $4}'
  read -rp "Enter backup filename to restore: " backup_file </dev/tty
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
      read -rp "Do you want to update your n8n instance to version $backup_version? (y/N): " confirm </dev/tty
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
