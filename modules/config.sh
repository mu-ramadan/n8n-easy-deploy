#!/usr/bin/env bash
# modules/config.sh
# Functions for initializing configuration and validating environment variables.

validate_env() {
  local required_vars=(
    N8N_PORT
    N8N_ENCRYPTION_KEY
    N8N_RUNNERS_ENABLED
    DB_TYPE
    DB_HOST
    DB_PORT
    DB_USER
    DB_PASS
    DB_NAME
    REDIS_HOST
    REDIS_PORT
    REDIS_PASS
    AWS_BUCKET
    AWS_REGION
    DOMAIN_NAME
    USER_EMAIL
    UPDATE_INTERVAL
  )

  for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" "$ENV_FILE"; then
      log "Error: ${var} is not set in $ENV_FILE"
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
services:
  n8n:
    image: n8nio/n8n:latest
    env_file:
      - .env
    restart: unless-stopped
    ports:
      - "0.0.0.0:${N8N_PORT}:${N8N_PORT}"
    depends_on:
      - postgres
      - redis
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_RUNNERS_ENABLED=${N8N_RUNNERS_ENABLED}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - DB_TYPE=${DB_TYPE}
      - DB_POSTGRESDB_HOST=${DB_HOST}
      - DB_POSTGRESDB_PORT=${DB_PORT}
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASS}
      - DB_POSTGRESDB_DATABASE=${DB_NAME}
      - QUEUE_BULL_REDIS_HOST=${REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASS}
      - EXECUTIONS_MODE=${EXECUTIONS_MODE}
      - QUEUE_MODE=${QUEUE_MODE}
      - LOG_LEVEL=${LOG_LEVEL}
      - NODE_FUNCTION_ALLOW_EXTERNAL=${NODE_FUNCTION_ALLOW_EXTERNAL}
      - AWS_BUCKET=${AWS_BUCKET}
      - AWS_REGION=${AWS_REGION}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - DOMAIN_NAME=${DOMAIN_NAME}
      - SSL_CERT=${SSL_CERT}
      - SSL_KEY=${SSL_KEY}
      - USER_EMAIL=${USER_EMAIL}
      - UPDATE_INTERVAL=${UPDATE_INTERVAL}
      - EXECUTIONS_TIMEOUT=${EXECUTIONS_TIMEOUT}
      - WEBHOOK_TUNNEL_URL=${WEBHOOK_TUNNEL_URL}

  postgres:
    image: postgres:16-alpine
    env_file:
      - .env
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASS}
      - POSTGRES_DB=${DB_NAME}
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

  # Check AWS credentials (from modules/aws.sh)
  check_aws_credentials
}
