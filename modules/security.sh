#!/usr/bin/env bash
# modules/security.sh
# Functions to secure and harden the server for production.
# This includes setting up UFW, hardening SSH, installing fail2ban,
# applying sysctl parameters, and basic Docker daemon hardening.

secure_ufw() {
  log "Configuring UFW firewall..."
  if ! command -v ufw >/dev/null 2>&1; then
    log "UFW not found. Installing UFW..."
    sudo apt-get update && sudo apt-get install -y ufw
  fi
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  local n8n_port
  n8n_port=$(grep '^N8N_PORT=' "$ENV_FILE" | cut -d= -f2)
  sudo ufw allow "$n8n_port"/tcp
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw --force enable
  log "UFW configured and enabled."
}

harden_ssh() {
  log "Hardening SSH configuration..."
  local ssh_config="/etc/ssh/sshd_config"
  sudo cp "$ssh_config" "${ssh_config}.bak"
  sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
  sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$ssh_config"
  sudo sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$ssh_config"
  sudo systemctl restart sshd
  log "SSH hardened: Root login and password authentication disabled."
}

install_fail2ban() {
  log "Installing and configuring fail2ban..."
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y fail2ban
  fi
  if [ ! -f /etc/fail2ban/jail.local ]; then
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 5
EOF
  fi
  sudo systemctl restart fail2ban
  log "fail2ban installed and configured."
}

apply_sysctl_hardening() {
  log "Applying kernel parameter hardening..."
  local sysctl_conf="/etc/sysctl.d/99-hardening.conf"
  sudo tee "$sysctl_conf" > /dev/null <<EOF
# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
# Enable TCP SYN cookies
net.ipv4.tcp_syncookies = 1
# Log martians
net.ipv4.conf.all.log_martians = 1
EOF
  sudo sysctl --system
  log "Kernel parameters applied for network security."
}

harden_docker() {
  log "Applying basic Docker daemon hardening..."
  if ! grep -q '"userns-remap":' /etc/docker/daemon.json 2>/dev/null; then
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "userns-remap": "default"
}
EOF
    sudo systemctl restart docker
    log "Docker daemon configured with user namespace remapping."
  else
    log "Docker daemon already hardened with user namespace remapping."
  fi
}

secure_server() {
  log "Starting server hardening..."
  secure_ufw
  harden_ssh
  install_fail2ban
  apply_sysctl_hardening
  harden_docker
  log "Server hardening completed."
}
