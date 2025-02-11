<!-- Banner Image -->
<p align="center">
  <img src="assets/banner.png" alt="n8n Easy Deploy Banner" width="800">
</p>

<h1 align="center">n8n Easy Deploy</h1>

<p align="center">
  <a href="https://github.com/yourusername/n8n-easy-deploy/actions">
    <img src="https://img.shields.io/github/workflow/status/yourusername/n8n-easy-deploy/CI?style=for-the-badge" alt="CI Status">
  </a>
  <a href="https://github.com/yourusername/n8n-easy-deploy/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/yourusername/n8n-easy-deploy?style=for-the-badge" alt="License">
  </a>
  <a href="https://github.com/yourusername/n8n-easy-deploy/issues">
    <img src="https://img.shields.io/github/issues/yourusername/n8n-easy-deploy?style=for-the-badge" alt="Issues">
  </a>
  <a href="https://github.com/yourusername/n8n-easy-deploy">
    <img src="https://img.shields.io/github/stars/yourusername/n8n-easy-deploy?style=for-the-badge" alt="Stars">
  </a>
</p>

<p align="center">
  <strong>A simple, modular, and secure deployment tool for self-hosted n8n instances.</strong>
</p>

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

**n8n Easy Deploy** streamlines the entire lifecycle of your self-hosted n8n instance—from initial configuration and service startup to blue-green updates and automated backups/restorations. Its modular architecture ensures that even complex deployments are easy to manage.

Key benefits include:

- **Zero Downtime Deployments:**  
  Blue-green deployments keep your service running without interruption.
- **Automated Backups & Restores:**  
  Securely back up your data locally or to AWS S3.
- **Dynamic Traefik Integration:**  
  Automatically manage domain names and SSL certificates.
- **User-Friendly:**  
  Designed for both technical and non-technical users with robust error handling and logging.

---

## Features

- **Modular Architecture:**  
  Organized configuration files, function libraries, Docker Compose templates, and Traefik configurations for easy customization.
  
- **Full Deployment & Updates:**  
  Seamlessly deploy new instances or update existing ones using blue-green deployment techniques.
  
- **Automated Backups & Restores:**  
  Schedule and execute secure backups for your database, configuration, workflows, and credentials.
  
- **Traefik Integration:**  
  Simplify domain and SSL management with dynamic Traefik configuration.
  
- **Robust Error Handling:**  
  Comprehensive logging and error detection ensure that issues are quickly identified and resolved.

---

## Repository Structure

```plaintext
n8n-easy-deploy/
├── README.md                  # Project documentation
├── LICENSE                    # License file (MIT recommended)
├── Makefile                   # Simplify common tasks
├── config/
│   ├── .env.example           # Sample environment variables
│   ├── docker-compose.yml     # Docker Compose template
│   └── traefik/
│       └── n8n.yaml.template  # Traefik configuration template
├── scripts/
│   ├── n8n-ctl.sh           # Main entrypoint script
│   └── functions.sh         # Function definitions (deploy, backup, etc.)
├── backups/                   # Directory for backup archives (created at runtime)
└── logs/                      # Log files directory (created at runtime)
Prerequisites
Before getting started, ensure you have the following installed:

Docker & Docker Compose:
Required for containerizing and orchestrating services.

AWS CLI:
Needed for backup/restore operations to/from AWS S3.

Traefik:
For managing domain and SSL automation.

Sudo Privileges:
Necessary for system-level changes (e.g., reloading Traefik).

Installation
Clone the repository and navigate into the project directory:

bash
Copy
git clone https://github.com/yourusername/n8n-easy-deploy.git
cd n8n-easy-deploy
Set up your environment by copying and editing the sample environment file:

bash
Copy
cp config/.env.example config/.env
# Then, open config/.env in your preferred editor and update the values.
Ensure the main script is executable:

bash
Copy
chmod +x scripts/n8n-ctl.sh
Configuration
config/.env
This file contains settings for n8n, your database, AWS S3, and domain/SSL configurations. Copy from .env.example and modify as required.

config/docker-compose.yml
Defines the Docker services (n8n, PostgreSQL, Redis) using the variables from your .env file.

config/traefik/n8n.yaml.template
Template for Traefik’s dynamic configuration. Placeholders here are replaced by values from .env during deployment.

Usage
Interactive Mode
Launch the main script to access an interactive menu:

bash
Copy
./scripts/n8n-ctl.sh
The menu offers options to:

Deploy a new instance
Update the instance
Backup and restore your setup
Perform system checks
Command-Line Mode
You can also execute commands directly:

bash
Copy
./scripts/n8n-ctl.sh deploy        # Full deployment (blue-green update)
./scripts/n8n-ctl.sh update        # Update your instance
./scripts/n8n-ctl.sh backup        # Backup database & configuration
./scripts/n8n-ctl.sh restore       # Restore from backup (AWS S3 or local)
./scripts/n8n-ctl.sh backupwc      # Backup workflows & credentials
./scripts/n8n-ctl.sh restorewc     # Restore workflows & credentials
./scripts/n8n-ctl.sh check         # Run system checks and repairs
./scripts/n8n-ctl.sh help          # Display help message
Makefile Commands
For convenience, use the provided Makefile to execute common tasks:

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
Run commands like so:

bash
Copy
make deploy
make update
# ... and so on.
Troubleshooting & Logs
All logs are stored in the logs/ directory. In case of an error, detailed messages (with timestamps) are logged in n8n-ctl.log. Use these logs to diagnose and resolve issues.

Contributing
Contributions, bug reports, and feature requests are welcome!

Fork the repository.
Create a new branch for your feature or bug fix.
Commit your changes with clear messages.
Push to your fork and open a pull request.
For more details, check the Issues section.

License
This project is licensed under the MIT License.

<p align="center"> <em>Happy Deploying! 🚀</em> </p> ```