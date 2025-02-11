# 🚀 n8n Easy Deploy | Self-Host Automation Made Simple

![n8n Logo](https://n8n.io/n8n-logo.svg)  
*Professional workflow automation with zero DevOps hassle*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/yourusername/n8n-easy-deploy?color=success)](https://github.com/yourusername/n8n-easy-deploy/releases)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-2496ED.svg?logo=docker)](https://www.docker.com/)

A **production-grade deployment system** for n8n featuring automatic SSL, bulletproof backups, and seamless updates. Designed for engineers who value reliability over complexity.

---

## 🔥 Features That Save Time

|   | Capability | Description |
|---|------------|-------------|
| 🛡️ | **Military-Grade Security** | Auto-configured HTTPS via Let's Encrypt + Traefik proxy |
| 🔄 | **Zero-Downtime Updates** | Blue/green deployment strategy built-in |
| 💾 | **Smart Backups** | 1-command backup/restore for DB + workflows + credentials |
| 🧩 | **Modular Architecture** | Clean separation of configs, scripts, and operational logic |
| 📊 | **Enterprise Monitoring** | Built-in logging and health checks |

---

## 📂 Repository Structure

```bash
n8n-easy-deploy/
├── 📄 README.md                # Project documentation
├── 📄 LICENSE                  # MIT License
├── 📄 Makefile                 # Developer shortcuts
├── 📄 install.sh               # One-click installer
├── 📂 config/
│   ├── 📄 .env.example         # Configuration template
│   ├── 📄 docker-compose.yml   # Main service definition
│   └── 📂 traefik/
│       └── 📄 n8n.yaml.template # Reverse proxy configuration
├── 📂 scripts/
│   ├── 📄 n8n-ctl.sh           # Control panel CLI
│   └── 📄 functions.sh         # Core logic library
├── 📂 backups/                 # Automatic backup storage
└── 📂 logs/                    # Operational logs
🛠️ Installation in 3 Commands
bash
Copy
# 1. Clone repository
git clone https://github.com/yourusername/n8n-easy-deploy.git
cd n8n-easy-deploy

# 2. Run installer (will request sudo for Docker setup)
chmod +x install.sh && ./install.sh

# 3. Start control panel
cd /opt/n8n-easy-deploy
./scripts/n8n-ctl.sh
First-Time Setup Checklist:

Edit config/.env (domain, email, credentials)

Open ports 80/443 in firewall

Point DNS to your server IP

💻 Usage Examples
Interactive Mode
bash
Copy
./scripts/n8n-ctl.sh  # Launches menu-driven interface
Command-Line Mode
Command	Action
deploy	Full initial deployment
update --strategy=blue-green	Zero-downtime update
backup --full --cloud=s3	Backup to AWS S3
restore --file=backups/n8n-2023-09-01.tar.gz	Restore specific backup
check --networking --ssl	Diagnostic checks
Deployment Diagram

🚨 Troubleshooting FAQ
Q: SSL certificate not generating?
A: Verify port 80 is open and DNS propagates correctly.

Q: Backup failing with permission errors?
A: Run sudo chown -R $USER:$USER backups/

Q: How to change domains post-deployment?
A: Update config/.env and run ./scripts/n8n-ctl.sh redeploy

🤝 Contributing
We welcome PRs! Please follow our guidelines:

Fork the repository

Create feature branch (git checkout -b feat/amazing-feature)

Commit changes

Push to branch

Open Pull Request

📜 License
MIT License - see LICENSE for details.
Not affiliated with n8n.io - just big fans of their work.