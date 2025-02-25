#!/usr/bin/env bash
# modules/aws.sh
# Functions for automating AWS authentication checks and configuration.

check_aws_credentials() {
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    log "AWS credentials found in .env file."
  elif [ -f "$HOME/.aws/credentials" ]; then
    log "AWS credentials file found at $HOME/.aws/credentials."
  else
    log "AWS credentials not found. Launching 'aws configure'..."
    aws configure < /dev/tty
    if [ $? -ne 0 ]; then
      log "Error: AWS configuration failed. Please configure your AWS credentials."
      exit 1
    else
      log "AWS configuration completed."
    fi
  fi
}
