<pre><code class="language-markdown">
# &#x1F680; n8n Easy Deploy

[![n8n Logo](https://n8n.io/n8n-logo.svg)](https://n8n.io/)

**Deploy a self-hosted n8n instance with a single command!**  n8n Easy Deploy provides a secure, modular, and easy-to-use solution for automating your workflows.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/yourusername/n8n-easy-deploy?color=success)](https://github.com/yourusername/n8n-easy-deploy/releases)
[![Build Status](https://img.shields.io/github/actions/workflow/status/yourusername/n8n-easy-deploy/main.yml?branch=main&amp;label=Build)](https://github.com/yourusername/n8n-easy-deploy/actions)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-2496ED.svg?logo=docker)](https://www.docker.com/)
[![Code Style: Prettier](https://img.shields.io/badge/Code%20Style-Prettier-yellow.svg)](https://prettier.io/)

---

## &#x2728; Get Started in Seconds! &#x2728;

To deploy n8n instantly, run the following command in your terminal.  This command securely downloads the installation script from GitHub and executes it:

**`curl -sSL https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh | sh`**

&#x60;&#x60;&#x60;bash
curl -sSL https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh | sh
&#x60;&#x60;&#x60;

**What this command does (and why it's safe):**

1.  **`curl -sSL`:** Securely downloads the `install.sh` script.
    *   `-s` (silent): Hides the progress bar.
    *   `-S` (show-error): Displays errors even in silent mode.
    *   `-L` (location): Follows redirects.
    *   `https://`: Uses a secure, encrypted connection.

2.  **`| sh`:** Executes the downloaded script.

**Before you run it:**

*   **Highly Recommended:** **[Review the `install.sh` script](https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh)** to see exactly what commands will be executed.
*   **Prerequisites:** Ensure you have Docker, Docker Compose, and root/sudo access. See the [Prerequisites](#-prerequisites) section below.
*   **Domain Name:** Have your domain already pointing to your server's IP address.

**After the installer runs:**

*   **Edit `.env`!** You *must* configure your domain and email in `/opt/n8n-easy-deploy/config/.env`. See [Post-Installation Configuration](#-post-installation-configuration-important) below.

---

## &#x1F4DD; Prerequisites

Before using the one-line installer, ensure you have:

*   **Docker:**  Install Docker Engine.
*   **Docker Compose:**  Install Docker Compose (usually comes with Docker Desktop).
*   **Root or Sudo Privileges:** The installer needs elevated privileges to install software and configure the system.
*   **A Domain Name:** You'll need a domain or subdomain pointing to your server's public IP address to use Let's Encrypt for automatic SSL certificates.
*   **Basic Linux knowledge**

---

## &#x1F6E0;&#xFE0F; Post-Installation Configuration (IMPORTANT!)

1.  **Edit the `.env` file:**

    &#x60;&#x60;&#x60;bash
    cd /opt/n8n-easy-deploy/config
    nano .env  # Or use your preferred text editor
    &#x60;&#x60;&#x60;

    *   **`DOMAIN_NAME` (Required):** Set this to your domain name (e.g., `n8n.example.com`).
    *   **`LETSENCRYPT_EMAIL` (Required):** Provide a valid email address for Let's Encrypt certificate registration.
    *   **`POSTGRES_PASSWORD` (Strongly Recommended):**  Change the default PostgreSQL password to a strong, unique password.
    *  Review and adjust other settings as needed.

2.  **(Re)deploy after editing `.env`:**

    &#x60;&#x60;&#x60;bash
    cd /opt/n8n-easy-deploy
    ./scripts/n8n-ctl.sh deploy
    &#x60;&#x60;&#x60;
    This applies your configuration changes.

---

## &#x2728; Features

- **Full Deployment:** Initializes configuration, starts services, and automatically configures domain/SSL.
- **Updates:** Supports manual blue-green deployments or a persistent auto-update service (optional).
- **Backup &amp; Restore:** Comprehensive backup solution:
    - Database &amp; Configuration:  Backs up the database and essential `config/` files.
    - Workflows &amp; Credentials: Separately backs up and restores n8n workflows and credentials.
- **Traefik Integration:**  Automatically generates dynamic configuration for custom domains and SSL.
- **Modular &amp; Robust:** Cleanly organized codebase.  Extensive error handling and logging.
- **Configuration via .env:**  Centralized configuration.
- **Health Checks:**  Includes Docker Compose health checks.

---

## &#x1F6E0;&#xFE0F; Usage (n8n-ctl.sh)

Manage your n8n instance with:

&#x60;&#x60;&#x60;bash
cd /opt/n8n-easy-deploy
./scripts/n8n-ctl.sh &lt;command&gt;
&#x60;&#x60;&#x60;

| Command       | Description                                                                                                                              |
|---------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `deploy`      | Performs a full deployment or re-deployment of n8n.  Reads the `.env` file, generates the Traefik config, and (re)starts the containers. |
| `update`      | **Manual Blue-Green Update:** Stops the existing containers, pulls the latest n8n image, and starts new containers.  Minimizes downtime. |
| `backup`      | Creates a backup of the database and configuration files in the `backups/` directory.                                                      |
| `restore`     | Restores the database and configuration from a backup file in the `backups/` directory.  You'll be prompted to select a backup file.     |
| `backupwc`    | Backs up n8n workflows and credentials using the n8n CLI (requires n8n CLI to be installed).                                            |
| `restorewc`   | Restores n8n workflows and credentials using the n8n CLI (requires n8n CLI to be installed).                                            |
| `check`       | Performs diagnostic checks to identify common problems and suggests solutions.                                                          |
| `logs`        | Displays logs for the n8n and Traefik containers.  Useful for troubleshooting.                                                        |
| `status`      | Shows the status of the Docker containers.                                                                                        |
| `stop`        | Stops the n8n and Traefik containers.                           |
| `start`       | Starts the n8n and Traefik containers.                           |

---

## &#x1F4C2; Repository Structure

&#x60;&#x60;&#x60;
n8n-easy-deploy/
├── README.md                # Project documentation
├── LICENSE                  # MIT License
├── Makefile                 # (Optional) Developer shortcuts (e.g., make deploy, make backup)
├── install.sh               # One-click installer script
├── config/                  # Configuration directory
│   ├── .env.example         # Template for environment variables (CRUCIAL)
│   ├── docker-compose.yml   # Docker Compose configuration file (defines services)
│   └── traefik/             # Traefik configuration
│       └── n8n.yaml.template # Template for dynamic Traefik configuration (generated from .env)
├── scripts/                 # Management scripts
│   ├── n8n-ctl.sh           # Main control script (handles deployments, backups, etc.)
│   └── functions.sh         # Helper functions for n8n-ctl.sh (improves readability)
├── backups/                 # Directory for storing backups (created automatically)
└── logs/                    # Directory for storing container logs (created automatically)
&#x60;&#x60;&#x60;

---

## &#x2699;&#xFE0F; Advanced Configuration

###  .env File

The `.env` file in the `config/` directory is **essential** for configuring your n8n deployment.  Here's a breakdown of the key variables:

| Variable             | Description                                                                                          | Default Value (Example)  |
|----------------------|------------------------------------------------------------------------------------------------------|--------------------------|
| `DOMAIN_NAME`        | Your domain name (or subdomain) for n8n.  **Required.**                                             | `n8n.example.com`         |
| `LETSENCRYPT_EMAIL` | Your email address, used for Let's Encrypt certificate registration.  **Required for SSL.**          | `your@email.com`           |
| `N8N_VERSION`       | The n8n Docker image version to use (e.g., `n8nio/n8n:latest`, `n8nio/n8n:0.200.0`).                  | `n8nio/n8n:latest`        |
| `DATA_FOLDER`        | Path to store n8n data (database, etc.). Keep this outside the project directory for persistence.  | `/data/n8n`             |
| `POSTGRES_USER`      | PostgreSQL database username.                                                                      | `n8n`                    |
| `POSTGRES_PASSWORD`   | PostgreSQL database password.  **Generate a strong, random password!**                               | `changeme`              |
| `POSTGRES_DB`        | PostgreSQL database name.                                                                          | `n8n`                    |
|`TRAEFIK_PUBLIC_PORT`| Port Traefik listens on (default `80`, `443`) | `443`|
| ...                  | Other n8n environment variables (see n8n documentation for complete list).                           | ...                      |

**Important:**  After changing configuration in `.env`, run `./scripts/n8n-ctl.sh deploy` to apply the changes.

### Docker Compose Configuration (`docker-compose.yml`)

The `docker-compose.yml` file defines the services for your n8n deployment.  It includes:

- **n8n:** The n8n container.  It uses the image specified in `.env`, mounts the data volume, and defines various environment variables.
- **postgres:**  The PostgreSQL database container.  It uses a persistent volume for data storage.  **Important for data

---

## &#x1F512; Security Considerations

*   **Change Default Passwords:**  Always change the default `POSTGRES_PASSWORD` in the `.env` file.
*   **Regular Backups:** Use the `backup` and `backupwc` commands to create regular backups.
*   **Keep Software Updated:**  Use the `update` command to update n8n and other components.  Consider enabling the auto-update service (if implemented).
*   **Firewall:** Configure a firewall to allow only necessary traffic (ports 80 and 443 for Traefik, and potentially port 5432 for external PostgreSQL access if needed).
*   **Monitor Logs:** Regularly check the logs for any errors or suspicious activity.

---

## &#x2753; Troubleshooting &amp; Support

*   **Check the logs:** `./scripts/n8n-ctl.sh logs`
*   **Run diagnostics:** `./scripts/n8n-ctl.sh check`
*   **Open an issue on GitHub:** If you encounter problems, please [open an issue](https://github.com/yourusername/n8n-easy-deploy/issues) with detailed information about the problem, including any error messages and the steps you've taken.

---

## &#x1F4DC; License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

</code></pre>
