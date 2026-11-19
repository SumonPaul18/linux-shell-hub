# 🚀 Master System Setup & Audit Script (v2.0)

> **A powerful, idempotent Bash automation tool for preparing Linux servers for Ansible management.**

This script is designed for DevOps Engineers and System Administrators who need to quickly audit, harden, and configure bare-metal servers, laptops, or VMs into production-ready **Ansible Managed Nodes**. It features deep hardware discovery, multi-interface network handling, and automated security hardening.

![License](https://img.shields.io/badge/License-MIT-green.svg)
![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?logo=gnu-bash)
![Platform](https://img.shields.io/badge/Platform-Linux-2C3E50?logo=linux)

---

## ✨ Key Features

*   **🔍 Deep System Audit:** Generates a detailed **Markdown (.md)** report including Hardware specs (CPU/RAM/Disk), Virtualization support (VT-x/AMD-V), and installed software stacks (Docker, K8s, Nginx, Ceph, etc.).
*   **🌐 Smart Network Configuration:** Automatically detects the primary interface with a default gateway. Supports static IP configuration while leaving other interfaces untouched. Handles Netplan (Ubuntu/Debian) and NMCLI (RHEL/CentOS) seamlessly.
*   **🛡️ Security Hardening:**
    *   Creates a dedicated admin user with **Passwordless Sudo** (ideal for Ansible).
    *   Configures SSH Key-based authentication.
    *   Disables Root login and optionally disables Password Authentication.
*   **🔄 Idempotent Execution:** Safe to run multiple times. It checks if a user or configuration already exists before applying changes, preventing errors and data loss.
*   **📊 Clean Reporting:** Outputs a structured, table-formatted audit report directly to the terminal and saves it as a `.md` file for documentation.

---

## 📋 Prerequisites

*   A Linux-based OS (Ubuntu 20.04+, Debian 10+, CentOS 7+, RHEL 8+, Fedora).
*   Root or Sudo privileges.
*   Basic knowledge of Linux networking (IP, Gateway, DNS).

---

## 🛠️ Installation & Usage

### 1. Download the Script

```bash
wget https://raw.githubusercontent.com/your-username/your-repo/main/master_setup.sh
chmod +x master_setup.sh
```

### 2. Run the Script

Execute the script with root privileges:

```bash
sudo bash master_setup.sh
```

### 3. Interactive Setup

The script will guide you through the following steps:
1.  **Audit:** It will first scan your system and display a detailed report.
2.  **Hostname:** Set a new hostname (defaults to current).
3.  **Network:** Choose to set a Static IP. It will auto-detect your current IP and Gateway as defaults.
4.  **User Creation:** Create a new admin user (e.g., `devops-admin`).
5.  **SSH Key:** Paste your Ansible Control Node's public key for passwordless access.

---

## 📄 Sample Audit Report

The script generates a professional Markdown report like this:

| Component | Details |
| :--- | :--- |
| **Form Factor** | Server (Inspur NF5280) |
| **CPU Model** | Intel(R) Xeon(R) Gold 6248R @ 3.00GHz |
| **Virtualization** | Yes (VT-x) |
| **RAM Total** | 128Gi |
| **Docker** | ✅ Installed (Docker version 24.0.7) |
| **Kubernetes** | ❌ Not Found |

---

## ⚙️ Configuration Details

### Network Handling
*   **Ubuntu/Debian:** Uses `netplan` to create a clean `01-static-config.yaml`. It automatically backs up conflicting files like `50-cloud-init.yaml`.
*   **RHEL/CentOS:** Uses `nmcli` to modify the connection profile.
*   **Multi-Interface:** Only the interface associated with the `default route` is configured for Static IP. Other interfaces remain in their current state (DHCP or Unmanaged).

### Security & SSH
*   **Sudoers:** The new user is added to `/etc/sudoers.d/` with `NOPASSWD:ALL` permission, which is required for Ansible to execute modules without interactive password prompts.
*   **SSH Hardening:**
    *   `PermitRootLogin no`: Prevents direct root access.
    *   `PasswordAuthentication no`: Enforced if an SSH Key is provided. If no key is provided, password auth remains enabled for initial access.

---

## 🤝 Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue or submit a pull request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

## 👤 Author

**Sumon**  
*Platform Engineer | DevOps Specialist | Cloud Infrastructure Architect*  
📍 Dhaka, Bangladesh  
🔗 [LinkedIn Profile](#) | 🌐 [Meghna Cloud](#)

---

### 💡 Tips for Best Results
*   **Backup:** Although the script is safe, always ensure you have a backup of critical data before running automation scripts on production servers.
*   **SSH Key:** Have your Ansible Control Node's public key (`~/.ssh/id_rsa.pub`) ready to copy-paste during the setup.
*   **Connectivity:** Ensure you have physical or console access to the server in case the network configuration changes disconnect your current SSH session.

---