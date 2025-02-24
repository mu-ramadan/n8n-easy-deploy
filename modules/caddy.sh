#!/usr/bin/env bash
# modules/caddy.sh
# Functions for configuring Caddy based on .env settings.

configure_domain_ssl() {
  local DOMAIN
  DOMAIN=$(grep '^DOMAIN_NAME=' "$ENV_FILE" | cut -d= -f2 || echo "")
  if [ -z "$DOMAIN" ]; then
    log "No DOMAIN_NAME defined in $ENV_FILE. Skipping domain configuration."
    return
  fi
  local N8N_PORT
  N8N_PORT=$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)
  local caddyfile="$CONFIG_DIR/Caddyfile"
  
  if grep -q '^SSL_CERT=' "$ENV_FILE" && grep -q '^SSL_KEY=' "$ENV_FILE"; then
    sudo tee "$caddyfile" > /dev/null <<EOF
{
    email {USER_EMAIL}
}

$DOMAIN {
    reverse_proxy 127.0.0.1:$N8N_PORT
    tls {SSL_CERT} {SSL_KEY}
}
EOF
    log "Caddyfile generated using custom SSL certificates for domain: $DOMAIN."
  else
    sudo tee "$caddyfile" > /dev/null <<EOF
{
    email {USER_EMAIL}
}

$DOMAIN {
    reverse_proxy 127.0.0.1:$N8N_PORT
}
EOF
    log "Caddyfile generated using Caddy's auto-TLS for domain: $DOMAIN."
  fi
  log "Restarting Caddy to apply configuration..."
  sudo systemctl restart caddy
  log "Caddy restarted and configuration applied."
}
