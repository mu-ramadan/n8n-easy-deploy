#!/usr/bin/env bash
# modules/config.sh
# Functions for initializing configuration and validating environment variables.

validate_env() {
  local var
  for var in N8N_PORT DB_USER DB_PASS AWS_BUCKET; do
    if ! grep -q "^${var}=" "$ENV_FILE"; then
      log "Error: ${var} not set in $ENV_FILE"
      exit 1
    fi
  done
}

init_config() {
  log "Initializing configuration..."
  mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_TEMPLATE" ]; then
      cp "$ENV_TEMPLATE" "$ENV_FILE"
      chmod 600 "$ENV_FILE"
      log "No .env file found. Template copied from .env.example to .env."
      log "IMPORTANT: Please edit $ENV_FILE with your desired settings."
    else
      log "Error: Neither .env nor .env.example exists in $CONFIG_DIR."
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
    env_file:
      - .env
    restart: unless-stopped
    ports:
      - "${N8N_PORT}:${N8N_PORT}"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    env_file:
      - .env
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

  # Check AWS credentials as part of initialization
  check_aws_credentials
}
