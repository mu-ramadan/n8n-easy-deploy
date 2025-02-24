#!/usr/bin/env bash
# modules/backup.sh
# Functions for backing up n8n and cleaning up old backups.

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

cleanup_old_backups() {
  log "Cleaning up old backups (keeping only the latest $RETENTION_COUNT)..."
  local backups
  mapfile -t backups < <(ls -1t "$BACKUP_DIR"/n8n-backup-*.tar.gz 2>/dev/null || true)
  if [ "${#backups[@]}" -gt "$RETENTION_COUNT" ]; then
    local i
    for ((i=RETENTION_COUNT; i<${#backups[@]}; i++)); do
      log "Deleting old backup: ${backups[$i]}"
      rm -f "${backups[$i]}"
    done
  else
    log "No old backups to clean up."
  fi
}
