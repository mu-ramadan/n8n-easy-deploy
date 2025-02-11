# &#x1F680; n8n Easy Deploy

**Deploy a self-hosted n8n instance with ONE COMMAND!**

[![n8n Logo](https://pbs.twimg.com/profile_images/1536335358803251202/-gASF0c6_400x400.png)](https://n8n.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## &#x2728; Get Started (It's *Really* Easy!)

Run this command in your terminal:

**`curl -sSL https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh | sh`**

&#x60;&#x60;&#x60;bash
curl -sSL https://raw.githubusercontent.com/yourusername/n8n-easy-deploy/main/install.sh | sh
&#x60;&#x60;&#x60;

**Important (After Installation):**

1.  **Open this file:** `/opt/n8n-easy-deploy/config/.env`
2.  **Edit these lines (REQUIRED):**
    *   `DOMAIN_NAME=your.domain.com`  (Replace with your domain)
    *   `LETSENCRYPT_EMAIL=your@email.com` (Your email)
    *   `POSTGRES_PASSWORD=aStrongPassword` (Choose a strong password!)
3. **Apply Changes**:
    &#x60;&#x60;&#x60;bash
    cd /opt/n8n-easy-deploy
    ./scripts/n8n-ctl.sh deploy
    &#x60;&#x60;&#x60;

That's it! Your n8n instance should be accessible at your domain.

---

## &#x1F50D; What's Happening? (Simplified)

*   The command downloads a script (`install.sh`) and runs it.
*   The script sets up Docker, Docker Compose, n8n, and Traefik (for SSL).
*   The `.env` file holds your configuration (domain, email, etc.).  **You must edit it.**
* `n8n-ctl.sh deploy` command will run n8n instance.

---

## &#x1F4A1; Prerequisites (Quick List)

*   Docker &amp; Docker Compose installed.
*   A domain name pointing to your server.
*   Root/sudo access.

---
## &#x1F6A7; Manage n8n (n8n-ctl.sh)
&#x60;&#x60;&#x60;bash
cd /opt/n8n-easy-deploy
./scripts/n8n-ctl.sh &lt;command&gt;
&#x60;&#x60;&#x60;

| Command       | Description                                      |
|---------------|--------------------------------------------------|
| `deploy`      | (Re)Deploys n8n. Use after editing `.env`.        |
| `update`      | Updates n8n.        |
| `backup`      | Backs up your data.                               |
| `restore`     | Restores from a backup.                          |
| `logs`        | Shows logs.                                       |

(See the full documentation for more commands.)
---

## &#x1F512; Security

*   **Change `POSTGRES_PASSWORD`!**
*   Backup regularly: `./scripts/n8n-ctl.sh backup`
---

## &#x2753; Problems?

*   Check logs: `./scripts/n8n-ctl.sh logs`
*   [Open an issue on GitHub](https://github.com/yourusername/n8n-easy-deploy/issues)

---

## &#x1F4DC; License

MIT License - see [LICENSE](LICENSE).


