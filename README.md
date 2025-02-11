# n8n Easy Deploy

A simple, modular, and secure deployment tool for self-hosted n8n instances.

n8n Easy Deploy simplifies the entire lifecycle of your n8n deployment—from initial configuration and service startup to blue-green updates and automated backups/restorations. Designed with a modular architecture, it provides a robust, user-friendly solution with a clean and organized codebase.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Interactive Mode](#interactive-mode)
  - [Command-Line Mode](#command-line-mode)
- [Makefile Commands](#makefile-commands)
- [Troubleshooting & Logs](#troubleshooting--logs)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

**n8n Easy Deploy** is a modular, open-source deployment tool designed for self-hosted n8n instances. It streamlines deployment, update, and backup/restore processes for your automation workflows and configuration. Whether you’re a technical or non-technical user, this tool simplifies managing your n8n environment with:

- Zero downtime blue-green deployments.
- Automated backups of your database, configuration, and even workflows/credentials.
- Dynamic Traefik configuration for domain and SSL management.
- Robust error handling and logging.

---

## Features

- **Modular Architecture:**  
  Clean separation of configuration files, function libraries, Docker Compose templates, and Traefik configurations.

- **Full Deployment & Updates:**  
  Initialize your environment, start services, and perform blue-green updates with a single command.

- **Automated Backups & Restore:**  
  Securely back up your database and configuration locally or to AWS S3, and export/import your n8n workflows and credentials.

- **Traefik Integration:**  
  Automatically generate dynamic Traefik configurations for custom domains and SSL certificates.

- **Robust Error Handling:**  
  Built-in logging and error traps ensure issues are caught and reported, making maintenance easier.

---

## Repository Structure

```plaintext
n8n-easy-deploy/
├── README.md                # This file
├── LICENSE                  # License file (MIT License recommended)
├── Makefile                 # Simplify common tasks
├── config/
│   ├── .env.example         # Sample environment variables
│   ├── docker-compose.yml   # Docker Compose file template
│   └── traefik/
│       └── n8n.yaml.template  # Traefik dynamic configuration template
├── scripts/
│   ├── n8n-ctl.sh           # Main entrypoint script
│   └── functions.sh         # All function definitions (deployment, backup, restore, etc.)
├── backups/                 # Directory for backup archives (created at runtime)
└── logs/                    # Log files directory (created at runtime)
Prerequisites
Docker and Docker Compose
Ensure Docker and Docker Compose are installed on your system.

AWS CLI
Required for backup/restore to/from AWS S3 (if used).

Traefik
Must be installed and running for domain/SSL automation.

Sudo Privileges
Required for system-level changes (e.g., reloading Traefik).

Installation
Clone the Repository:

bash
Copy
git clone https://github.com/yourusername/n8n-easy-deploy.git
cd n8n-easy-deploy
Set Up Environment Variables:

Copy the sample environment file and edit it with your configuration:

bash
Copy
cp config/.env.example config/.env
# Open config/.env with your favorite editor and update the values.
Review Docker Compose and Traefik Templates:

Check the files in the config/ directory and update them as needed.

Make Scripts Executable:

bash
Copy
chmod +x scripts/n8n-ctl.sh
Configuration
config/.env:
Contains settings for n8n, database, AWS S3, and domain/SSL. Copy from .env.example and update as required.

config/docker-compose.yml:
Defines the Docker services (n8n, PostgreSQL, Redis) and uses environment variables from .env.

config/traefik/n8n.yaml.template:
Template for Traefik’s dynamic configuration. Placeholders are replaced by values from .env during deployment.

Usage
Interactive Mode
Run the main script to display an interactive menu:

bash
Copy
./scripts/n8n-ctl.sh
The menu includes options to:

Deploy a new instance
Update the instance
Create or restore backups (for DB/config and workflows/credentials)
Perform system checks
Command-Line Mode
Execute specific commands directly:

bash
Copy
./scripts/n8n-ctl.sh deploy        # Full deployment (blue-green update)
./scripts/n8n-ctl.sh update        # Update instance (manual update or toggle auto-update)
./scripts/n8n-ctl.sh backup        # Backup database & configuration
./scripts/n8n-ctl.sh restore       # Restore backup from AWS S3 or local storage
./scripts/n8n-ctl.sh backupwc      # Backup workflows & credentials
./scripts/n8n-ctl.sh restorewc     # Restore workflows & credentials
./scripts/n8n-ctl.sh check         # Check and repair common issues
./scripts/n8n-ctl.sh help          # Display help message
Makefile Commands
A Makefile is provided to simplify common tasks:

makefile
Copy
.PHONY: deploy update backup restore backupwc restorewc help

deploy:
	./scripts/n8n-ctl.sh deploy

update:
	./scripts/n8n-ctl.sh update

backup:
	./scripts/n8n-ctl.sh backup

restore:
	./scripts/n8n-ctl.sh restore

backupwc:
	./scripts/n8n-ctl.sh backupwc

restorewc:
	./scripts/n8n-ctl.sh restorewc

help:
	./scripts/n8n-ctl.sh help
Run commands via:

bash
Copy
make deploy
make update
# ... and so on.
Troubleshooting & Logs
All logs are stored in the logs/ directory.
If a command fails, detailed error messages (with timestamps) are logged in n8n-ctl.log.
Check these logs to diagnose issues.
Contributing
Contributions, bug reports, and feature requests are welcome!

Fork the repository.
Create a new branch for your feature or bug fix.
Commit your changes with clear commit messages.
Push to your fork and open a pull request.
For more details, please check the Issues section or open a new issue.