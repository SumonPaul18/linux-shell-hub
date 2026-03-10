# 🚀 Initial Linux Config (Production Ready)

A fully automated Bash script to set up a secure, production-ready Ubuntu server from scratch. This script handles user creation, network configuration, SSH hardening, and prepares the server for **Ansible automation**.

## ✨ Features

- **🔐 Flexible Authentication:** Supports SSH Key, Password, or Both (Hybrid Mode).
- **🛡️ Security Hardening:** Disables Root login, configures UFW Firewall, and installs Fail2Ban.
- **🌐 Static IP Setup:** Automatically configures Netplan for static networking (backups old configs).
- **🤖 Ansible Ready:** Ensures Python3 is installed and SSH is configured for immediate Ansible connectivity.
- **⚡ Auto-Detection:** Automatically detects the primary network interface if not specified.
- **📦 Essential Tools:** Installs common utilities (`vim`, `curl`, `git`, `htop`, etc.).

---

## 📂 Repository Structure

```text
initial-linux-config/
├── README.md              # This guideline file
├── config.env             # Configuration file (Edit this before running)
└── setup-prod-server.sh   # Main automation script
```

---

## 🛠️ Prerequisites

- A fresh Ubuntu Server (20.04 / 22.04 / 24.04).
- Root access (`sudo su`).
- Internet connection.
- (Optional) Your SSH Public Key (`~/.ssh/id_ed25519.pub`).

---

## 🚀 Quick Start Guide

### Step 1: Clone the Repository

First, clone this repository to your server or local machine.

# Clone the specific directory or the whole repo
```bash
git clone https://github.com/SumonPaul18/linux-shell-hub.git
```
# Navigate to the script directory
```
cd linux-shell-hub/initial-linux-config/v1.0
```

### Step 2: Configure `config.env`

Before running the script, you **must** edit the `config.env` file with your server details.

```bash
nano config.env
```

#### 🔧 Key Configuration Options:

| Variable | Description | Example |
| :--- | :--- | :--- |
| `NEW_USERNAME` | Your new admin username | `sumon` |
| `NEW_USER_PASSWORD` | User password (Leave empty for Key-only) | `StrongPass123!` |
| `SSH_PUBLIC_KEY` | Your SSH Public Key (Starts with `ssh-ed25519`) | `ssh-ed25519 AAAA...` |
| `STATIC_IP_CIDR` | Static IP with CIDR notation | `192.168.0.63/24` |
| `GATEWAY` | Your network gateway | `192.168.0.1` |
| `DNS_SERVERS` | DNS servers (comma-separated) | `8.8.8.8,1.1.1.1` |
| `NETWORK_INTERFACE` | Leave empty for auto-detect | `ens18` or `` |
| `DISABLE_ROOT_LOGIN` | Set `yes` to block root SSH login | `yes` |

> **💡 Tip:** You can use **SSH Key only**, **Password only**, or **Both**.
> - **Key Only:** Fill `SSH_PUBLIC_KEY`, leave `NEW_USER_PASSWORD` empty.
> - **Password Only:** Fill `NEW_USER_PASSWORD`, leave `SSH_PUBLIC_KEY` empty.
> - **Both:** Fill both fields.

### Step 3: Make the Script Executable

Grant execution permission to the script.

```bash
chmod +x server-setup.sh
```

### Step 4: Run the Script

Execute the script as **root**.

# Switch to root if you are not already
```
sudo su -
```
# Run the setup
```
./server-setup.sh
```

The script will:
1. Update the system.
2. Create the user and set up authentication.
3. Configure Static IP (and backup old Netplan files).
4. Harden SSH settings.
5. Install Firewall & Fail2Ban.
6. Display your **Ansible Inventory Snippet** at the end.

---

## 🔍 Post-Installation Verification

After the script finishes, verify the setup:

1. **Test SSH Connection** (Open a new terminal):
   ```bash
   ssh sumon@192.168.0.63
   ```
2. **Check Network:**
   ```bash
   ip a
   ping -c 4 google.com
   ```
3. **Check Security:**
   ```bash
   sudo ufw status
   sudo systemctl status fail2ban
   ```
4. **Test Ansible Connectivity:**
   Copy the snippet shown at the end of the script into your `inventory.ini` and run:
   ```bash
   ansible all -i inventory.ini -m ping
   ```

---

## 🔄 How to Rollback Network Changes

If the network configuration fails and you lose connection:
1. Access the server via **Proxmox Console** or physical monitor.
2. Go to `/etc/netplan/`.
3. Restore the backup file:
   ```bash
   cd /etc/netplan/
   ls -l *.bak  # Find the backup file
   sudo mv 01-netcfg.yaml.disabled.TIMESTAMP.bak 01-netcfg.yaml
   sudo netplan apply
   ```

---

## 🤝 Contributing

Feel free to fork this repository, suggest improvements, or submit pull requests. For issues, please open a ticket on GitHub.

---

**Created by:** [Sumon Paul](https://github.com/SumonPaul18)  
**Focus:** DevOps, Cloud Infrastructure, and Automation.
