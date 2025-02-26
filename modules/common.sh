#!/usr/bin/env bash
# modules/common.sh
# Common functions for logging, error handling, and dependency checks.

log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*" | tee -a "$LOG_FILE"
}

notify_error() {
  local exit_code=$?
  log "ERROR: Command failed (exit code ${exit_code}): ${BASH_COMMAND}"
}
trap notify_error ERR
trap 'log "Interrupted by signal"; exit 130' SIGINT SIGTERM

check_dependencies() {
  log "Checking required software..."
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
  else
    log "Docker is already installed."
  fi
  if ! docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin not found. Installing Docker Compose plugin..."
    log "Importing Caddy GPG key..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.gpg > /dev/null
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
  else
    log "Docker Compose plugin is already installed."
  fi
  if ! command -v aws >/dev/null 2>&1; then
    log "AWS CLI not found. Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
  else
    log "AWS CLI is already installed."
  fi
}
