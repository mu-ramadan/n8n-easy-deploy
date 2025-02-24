# n8n Easy Deploy

**n8n Easy Deploy** is a fully modular, production‑ready deployment GUI for self‑hosted n8n.

## Overview

This repository provides a complete solution to:
- **Deploy/Update** your n8n instance using Docker‑Compose with blue-green (zero downtime) updates.
- **Configure domain/SSL** automatically using Caddy (with auto‑TLS via Let’s Encrypt or custom certificates).
- **Backup/Restore** your n8n instance with version checking and instance adjustment.
- **Diagnose & Repair** common issues.
- **Secure & Harden** your server using advanced security measures (firewall, SSH hardening, fail2ban, sysctl tweaks, Docker hardening).
- **Automate AWS Authentication** by checking for credentials and prompting for configuration if needed.
- **Best Practices:**  
  - Persistent user data (via Docker volumes; consider Kubernetes with Rook for multi-node deployments).  
  - Nightly backups (via an attached container or cron job) with a short retention period (e.g., two weeks).  
  - Handling missed executions with queue mode or an external caching proxy.

## Repository Structure

n8n-easy-deploy/ ├── README.md # This file. ├── .env.example # Copy this to .env and edit with your desired settings. ├── docker-compose.yml # Defines n8n, PostgreSQL, and Redis with persistent volumes. ├── docker-compose.caddy.yml # Defines the Caddy reverse proxy. ├── Caddyfile # Base Caddy configuration. ├── modules/ # Modular scripts: │ ├── common.sh # Logging, error handling, dependency checks. │ ├── config.sh # Environment initialization and validation. │ ├── deploy.sh # Deployment functions (full deploy and blue-green updates). │ ├── update.sh # Update functions and persistent auto-update management. │ ├── backup.sh # Backup functions (with version recording). │ ├── restore.sh # Restore functions (with version compatibility check and instance adjustment). │ ├── check.sh # Diagnostic and repair functions. │ ├── caddy.sh # Caddy configuration functions. │ ├── aws.sh # AWS authentication and credential check. │ └── security.sh # Advanced server hardening functions. └── n8n-easy-deploy.sh # Main interactive deployment GUI.

bash
Copy

## Getting Started

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/yourusername/n8n-easy-deploy.git
   cd n8n-easy-deploy
Configure Your Environment:

Copy the example file and update it:

bash
Copy
cp .env.example .env
Edit .env and set:

n8n Settings: N8N_PORT, N8N_ENCRYPTION_KEY
Basic Authentication (optional): N8N_BASIC_AUTH_ACTIVE, N8N_BASIC_AUTH_USER, N8N_BASIC_AUTH_PASSWORD
Database: DB_HOST, DB_USER, DB_PASS, DB_NAME
Redis: REDIS_HOST, REDIS_PASS
Queue/Execution Mode: EXECUTIONS_MODE, QUEUE_MODE
Logging: LOG_LEVEL
AWS S3: AWS_BUCKET, AWS_REGION
Domain & SSL: DOMAIN_NAME, optionally SSL_CERT and SSL_KEY
User Email: USER_EMAIL
Auto Update Interval: UPDATE_INTERVAL
Launch the Deployment GUI:

Make the main script executable and run it:

bash
Copy
chmod +x n8n-easy-deploy.sh
./n8n-easy-deploy.sh
Use the interactive menu to deploy, update, create backups, restore backups, check/repair, or secure/harden your server.

Production Considerations:

User Data: Persistent volumes for PostgreSQL and Redis ensure user data remains intact. For multi-node deployments, consider Kubernetes with Rook.
Backups: Nightly backups can be automated using a separate container or cron job.
High Availability: For 100% uptime, consider running n8n in queue mode and deploying a caching proxy.
Security: Use the "Secure and Harden Server" option to apply advanced hardening measures.
AWS: AWS authentication is automated; credentials are checked and you’ll be prompted to run aws configure if needed.
Happy deploying with n8n Easy Deploy!

makefile
Copy
