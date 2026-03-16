# 🚀 Universal Linux Server Setup Script

<div align="left">

![Version](https://img.shields.io/badge/version-3.0-blue?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Linux-orange?style=for-the-badge)
![Bash](https://img.shields.io/badge/bash-✓-brightgreen?style=for-the-badge&logo=gnu-bash)

**এক কমান্ডে প্রফেশনাল সার্ভার প্রস্তুত করুন!**  
*Prepare Production-Ready Linux Servers in Minutes*

</div>

---

## 📋 Table of Contents

- [📖 Overview](#-overview)
- [✨ Features](#-features)
- [🖥️ Supported Systems](#️-supported-systems)
- [📦 Prerequisites](#-prerequisites)
- [⬇️ Installation](#️-installation)
- [🎯 Quick Start](#-quick-start)
- [⚙️ Configuration Guide](#️-configuration-guide)
- [🔧 Advanced Usage](#-advanced-usage)
- [📁 File Structure](#-file-structure)
- [🐛 Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [👨‍💻 Author](#-author)

---

## 📖 Overview

### English
**Universal Linux Server Setup Script** is a powerful, automated bash script designed for DevOps engineers and system administrators. It streamlines the initial server configuration process across multiple Linux distributions with intelligent OS detection, dynamic network configuration, and production-ready optimizations.

### বাংলা (বাংলাদেশ)
**ইউনিভার্সাল লিনাক্স সার্ভার সেটআপ স্ক্রিপ্ট** হলো একটি শক্তিশালী অটোমেটেড বাশ স্ক্রিপ্ট যা ডেভঅপস ইঞ্জিনিয়ার এবং সিস্টেম অ্যাডমিনিস্ট্রেটরদের জন্য তৈরি করা হয়েছে। এটি একাধিক লিনাক্স ডিস্ট্রিবিউশনে সার্ভারের প্রাথমিক কনফিগারেশন প্রসেসকে সহজ করে - স্মার্ট OS ডিটেকশন, ডাইনামিক নেটওয়ার্ক কনফিগারেশন এবং প্রোডাকশন-রেডি অপ্টিমাইজেশন সহ।

### 🔑 Key Benefits
| Benefit | Description |
|---------|-------------|
| ⚡ **Time Saving** | Configure servers in 2-3 minutes instead of 30+ minutes manually |
| 🔒 **Consistency** | Eliminate human errors with standardized configurations |
| 🌐 **Multi-OS** | Single script works on Ubuntu, Debian, CentOS, AlmaLinux, RHEL |
| 🔄 **Reversible** | Automatic backups allow easy rollback if needed |
| 📝 **Documentation** | Clean logs and structured output for audit trails |

---

## ✨ Features

```bash
✅ Intelligent OS Detection & Package Management
✅ Dynamic Network Interface Configuration
✅ Modern Netplan Syntax (routes instead of deprecated gateway4)
✅ Secure File Permissions (chmod 600 for netplan files)
✅ Automatic Backup System (/etc/netplan/backup_*)
✅ Hostname & FQDN Configuration
✅ Clean /etc/hosts Management (CIDR-free IP entries)
✅ Dependency Installation (Python, GCC, SSL, Pip, etc.)
✅ System Optimization (Swap disable, Firewall management)
✅ Silent Mode Execution (Clean, professional output)
✅ Pre-validation with netplan generate
✅ Error Handling & Logging
```

### 🌐 Network Configuration Options
প্রতিটি নেটওয়ার্ক ইন্টারফেসের জন্য ৩টি অপশন:

| Option | Description | Use Case |
|--------|-------------|----------|
| `1) No-IP (Disable)` | Interface remains up but no IP assigned | Dedicated storage network, future use |
| `2) Static IP` | Manual IP, Gateway, DNS configuration | Management network, production services |
| `3) DHCP` | Automatic IP assignment via DHCP | Testing environments, temporary setups |

---

## 🖥️ Supported Systems

### ✅ Fully Tested
```bash
🐧 Ubuntu: 20.04 LTS, 22.04 LTS, 24.04 LTS
🐧 Debian: 11 (Bullseye), 12 (Bookworm)
🎩 CentOS: 7, 8, 9 Stream
🎩 AlmaLinux: 8, 9
🎩 Rocky Linux: 8, 9
🎩 RHEL: 8, 9
```

### 🔄 Partially Supported (Community Tested)
```bash
🐧 Linux Mint, Pop!_OS, Zorin OS
🎩 Fedora, Oracle Linux, CloudLinux
```

---

## 📦 Prerequisites

### Before Running the Script
```bash
# 1. Root or Sudo Access
sudo -v

# 2. Internet Connection (for package installation)
ping -c 3 8.8.8.8

# 3. Backup Important Data (Recommended)
#    Script creates config backups, but application data is your responsibility

# 4. Console/VNC Access (Recommended for network changes)
#    SSH sessions may disconnect during network reconfiguration
```

### ⚠️ Important Warning
> 🔴 **SSH Users:** If running remotely via SSH, network changes may disconnect your session. 
> 
> ✅ **Best Practice:** Use console access (Proxmox VNC, VMware Console, Physical KVM) or run with `screen`/`tmux`:
> ```bash
> sudo apt install screen -y
> screen -S server-setup
> sudo ./setup_server_v3.sh
> # Detach: Ctrl+A, then D
> # Reattach: screen -r server-setup
> ```

---

## ⬇️ Installation

### Method 1: Clone from GitHub (Recommended)
```bash
# Clone the repository
git clone https://github.com/SumonPaul18/linux-shell-hub.git
cd linux-shell-hub/universal-server-setup

# Make script executable
chmod +x setup_server_v3.sh

# Verify script integrity (optional)
sha256sum setup_server_v3.sh
```

### Method 2: Direct Download
```bash
# Download using curl
curl -O https://raw.githubusercontent.com/SumonPaul18/linux-shell-hub/main/universal-server-setup/setup_server_v3.sh

# OR using wget
wget https://raw.githubusercontent.com/SumonPaul18/linux-shell-hub/main/universal-server-setup/setup_server_v3.sh

# Make executable and run
chmod +x setup_server_v3.sh
```

### Method 3: One-Liner (Advanced Users)
```bash
# Download and execute in one command (use with caution)
curl -sSL https://raw.githubusercontent.com/SumonPaul18/linux-shell-hub/main/universal-server-setup/setup_server_v3.sh | sudo bash
```

---

## 🎯 Quick Start

### Step-by-Step Execution Guide

```bash
# 1. Navigate to script directory
cd ~/linux-shell-hub/universal-server-setup

# 2. Run with sudo
sudo ./setup_server_v3.sh
```

### Interactive Configuration Example
```bash
=== System Detection ===
[INFO] Detected: Debian/Ubuntu Family (apt + netplan)

=== Basic Configuration ===
Enter Hostname (e.g., controller): controller
Enter FQDN (e.g., controller.paulco.xyz): controller.paulco.xyz

=== Network Interface Detection ===
[INFO] Found 2 interface(s): enp6s18 enp6s19

[INFO] Configuring: enp6s18
Select configuration type for enp6s18:
1) No-IP (Disable)
2) Static IP
3) DHCP
#? 2
  Enter IP with CIDR (e.g., 192.168.68.69/24): 192.168.68.69/24
  Enter Gateway (e.g., 192.168.68.1): 192.168.68.1
  Enter DNS (comma separated, e.g., 8.8.8.8): 8.8.8.8,1.1.1.1

[INFO] Configuring: enp6s19
Select configuration type for enp6s19:
1) No-IP (Disable)
2) Static IP
3) DHCP
#? 1
[WARN] enp6s19 will be disabled (No-IP)

=== Applying Network Configuration ===
[INFO] Backup directory: /etc/netplan/backup_2026-03-16_0447
[WARN] Backed up: 00-installer-config.yaml
[INFO] Validating Netplan configuration...
[INFO] Configuration valid. Applying...
[INFO] Netplan applied successfully.

=== Configuring Hostname & Hosts ===
[INFO] Added to hosts: 192.168.68.69 -> controller.paulco.xyz

=== Installing Dependencies ===
[INFO] Dependencies installed (apt)

=== System Optimization ===
[INFO] Swap disabled.
[INFO] ufw disabled.

=== Configuration Complete! ===
Hostname : controller
FQDN     : controller.paulco.xyz
IPs      :
  - enp6s18: static (192.168.68.69/24)
  - enp6s19: none (N/A)

Backup Location: /etc/netplan/backup_2026-03-16_0447
Check network: ip -c a
Check hosts  : tail -n 5 /etc/hosts

Reboot now to apply all changes? (y/n): y
[INFO] Rebooting...
```

---

## ⚙️ Configuration Guide

### 📝 Input Parameters Explained

#### Hostname & FQDN
```bash
# Hostname: Short name for the system (used in prompts, logs)
# Example: controller, web01, db-primary

# FQDN: Fully Qualified Domain Name (for DNS resolution)
# Example: controller.paulco.xyz, web01.example.com

# Best Practice:
# - Use lowercase letters only
# - Avoid special characters except hyphens (-)
# - Keep it descriptive but concise
```

#### Network Interface Configuration

##### Static IP Format
```bash
# IP Address with CIDR notation (REQUIRED)
✅ Correct: 192.168.68.69/24
✅ Correct: 10.0.0.100/16
❌ Wrong: 192.168.68.69 (missing /24)
❌ Wrong: 192.168.68.69/255.255.255.0 (use CIDR, not subnet mask)

# Gateway: Default route for outbound traffic
✅ Correct: 192.168.68.1
✅ Correct: 10.0.0.1
❌ Wrong: 192.168.68.1/24 (gateway should be IP only)

# DNS: Comma-separated list of DNS servers
✅ Correct: 8.8.8.8,8.8.4.4
✅ Correct: 1.1.1.1
✅ Correct: 192.168.68.1,8.8.8.8 (local + public)
```

##### No-IP (Disable) Option
```yaml
# When selected, generates this netplan config:
enp6s19:
  optional: true
  addresses: []
  dhcp4: false
  dhcp6: false

# Benefits:
# - Interface remains manageable by system
# - No IP conflicts or routing issues
# - Can be enabled later without config changes
```

### 🔧 Generated Configuration Files

#### Netplan Configuration (`/etc/netplan/99-custom-config.yaml`)
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp6s18:
      addresses: [192.168.68.69/24]
      routes:
        - to: default
          via: 192.168.68.1
      nameservers:
        addresses: [8.8.8.8]
      optional: true
    enp6s19:
      optional: true
      addresses: []
      dhcp4: false
      dhcp6: false
```

#### Hosts File (`/etc/hosts`)
```bash
127.0.0.1   localhost
127.0.1.1   controller

# Custom Static IPs
192.168.68.69   controller.paulco.xyz controller # enp6s18
```
> ✅ Note: IP addresses in `/etc/hosts` are CIDR-free (clean format)

---

## 🔧 Advanced Usage

### 🔄 Rollback to Previous Configuration
```bash
# List available backups
ls -la /etc/netplan/backup_*/

# Restore a specific backup
sudo cp /etc/netplan/backup_2026-03-16_0447/00-installer-config.yaml /etc/netplan/
sudo netplan apply

# Or restore all files from backup
sudo cp /etc/netplan/backup_2026-03-16_0447/*.yaml /etc/netplan/
sudo netplan apply
```

### 🧪 Test Configuration Without Applying
```bash
# Generate and validate only (no changes applied)
sudo netplan generate
echo $?  # 0 = success, non-zero = error

# Preview the configuration
cat /etc/netplan/99-custom-config.yaml

# Test network connectivity before reboot
ping -c 3 8.8.8.8
nslookup google.com
```

### 📊 Post-Installation Verification
```bash
# Check network interfaces
ip -c a
ip route show

# Verify hostname resolution
hostnamectl
getent hosts controller.paulco.xyz

# Check installed dependencies
python3 --version
pip3 --version
gcc --version

# Verify disabled services
systemctl status ufw      # Should show inactive/dead
swapon --show             # Should return empty

# Check netplan file permissions (should be 600)
ls -l /etc/netplan/99-custom-config.yaml
```

### 🎨 Customize for Your Environment
```bash
# Edit the script to pre-configure values (for automated deployments)
nano setup_server_v3.sh

# Example: Set default values at the top of the script
DEFAULT_HOSTNAME="prod-web01"
DEFAULT_FQDN="prod-web01.paulco.xyz"
DEFAULT_PRIMARY_IP="10.0.0.50/24"
DEFAULT_GATEWAY="10.0.0.1"
DEFAULT_DNS="10.0.0.1,8.8.8.8"

# Then modify input section to use defaults with option to override
```

---

## 📁 File Structure

```
linux-shell-hub/
└── universal-server-setup/
    ├── setup_server_v3.sh          # Main executable script
    ├── README.md                    # This documentation
    ├── CHANGELOG.md                # Version history
    ├── examples/
    │   ├── config-ubuntu-static.yaml    # Example netplan config
    │   ├── config-centos-dhcp.yaml      # Example NM config
    │   └── hosts-file-sample.txt        # Sample /etc/hosts
    ├── tests/
    │   ├── test-os-detection.sh         # OS detection unit tests
    │   └── test-netplan-syntax.sh       # Netplan validation tests
    └── docs/
        ├── TROUBLESHOOTING.md           # Common issues & fixes
        ├── SECURITY-BEST-PRACTICES.md   # Hardening guidelines
        └── CONTRIBUTING.md              # How to contribute
```

---

## 🐛 Troubleshooting

### Common Issues & Solutions

#### 🔴 Issue: SSH disconnected after running script
```bash
# Cause: Network reconfiguration during active SSH session
# Solution:
# 1. Use console/VNC access for initial setup
# 2. Or use screen/tmux to maintain session:
screen -S setup
sudo ./setup_server_v3.sh
# If disconnected: ssh back in and run: screen -r setup
```

#### 🔴 Issue: "Permissions too open" warning
```bash
# Cause: Netplan requires 600 permissions for security
# Solution: Script automatically sets chmod 600
# Verify: 
ls -l /etc/netplan/99-custom-config.yaml
# Should show: -rw------- root root

# If still seeing warning, manually fix:
sudo chmod 600 /etc/netplan/99-custom-config.yaml
sudo netplan apply
```

#### 🔴 Issue: Netplan apply fails with syntax error
```bash
# Cause: Invalid YAML indentation or deprecated syntax
# Solution:
# 1. Check generated config:
cat /etc/netplan/99-custom-config.yaml

# 2. Validate syntax:
sudo netplan generate

# 3. Use online YAML validator: https://www.yamllint.com/

# 4. Restore backup if needed:
sudo cp /etc/netplan/backup_*/00-installer-config.yaml /etc/netplan/
sudo netplan apply
```

#### 🔴 Issue: No internet after reboot
```bash
# Diagnostic steps:
# 1. Check interface status:
ip link show

# 2. Verify IP assignment:
ip addr show enp6s18

# 3. Test gateway connectivity:
ping -c 3 192.168.68.1  # Replace with your gateway

# 4. Check DNS resolution:
nslookup google.com

# 5. Review netplan config:
sudo netplan --debug apply

# Common fixes:
# - Ensure CIDR notation in IP (e.g., /24)
# - Verify gateway is on same subnet as IP
# - Check if interface name matches actual hardware
```

#### 🔴 Issue: Script fails on unknown OS
```bash
# Cause: OS not in detection list
# Solution:
# 1. Check /etc/os-release:
cat /etc/os-release

# 2. Manually set environment variables before running:
export OS_ID="ubuntu"
export PKG_MGR="apt"
export NET_CONFIG_METHOD="netplan"
sudo -E ./setup_server_v3.sh

# 3. Or edit script to add your OS to detection logic
```

### 📞 Getting Help

1. **Check Logs:** Script output is logged to `/tmp/netplan_log.txt` on errors
2. **GitHub Issues:** Report bugs at [github.com/SumonPaul18/linux-shell-hub/issues](https://github.com/SumonPaul18/linux-shell-hub/issues)
3. **Community:** Join discussions in GitHub Discussions tab
4. **Emergency Rollback:** Use backup files in `/etc/netplan/backup_*/`

---

## 🤝 Contributing

We welcome contributions from the community! 🎉

### How to Contribute
```bash
# 1. Fork the repository
# 2. Create a feature branch:
git checkout -b feature/amazing-feature

# 3. Make your changes with clear commits
git commit -m "feat: add support for XYZ distribution"

# 4. Test thoroughly (use provided test scripts)
cd tests/
bash test-os-detection.sh

# 5. Push and create Pull Request
git push origin feature/amazing-feature
```

### Contribution Guidelines
- ✅ Follow existing code style (bash best practices)
- ✅ Add comments for complex logic
- ✅ Update README.md for new features
- ✅ Test on at least 2 different OS families
- ✅ Include error handling for new code paths
- ❌ No hardcoded credentials or sensitive data
- ❌ No breaking changes without major version bump

### Development Setup
```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/linux-shell-hub.git
cd linux-shell-hub/universal-server-setup

# Install testing tools (optional)
sudo apt install shellcheck bashunit -y

# Run linting before commit
shellcheck setup_server_v3.sh
```

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 Sumon Paul

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 👨‍💻 Author

<div align="center">

### Sumon Paul
**DevOps Engineer | Cloud Infrastructure Specialist**

[![GitHub](https://img.shields.io/badge/GitHub-SumonPaul18-181717?style=for-the-badge&logo=github)](https://github.com/SumonPaul18)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Sumon%20Paul-0A66C2?style=for-the-badge&logo=linkedin)](https://linkedin.com/in/sumonpaul)
[![Blog](https://img.shields.io/badge/Blog-paulco.xyz-FF6B6B?style=for-the-badge)](https://paulco.xyz)

> 🇧🇩 Based in Bangladesh | 🌍 Building Infrastructure for Tomorrow

</div>

### 🙏 Acknowledgments
- Netplan documentation team for excellent YAML schema docs
- Linux community for decades of open-source collaboration
- All contributors who help improve this script

---

<div align="center">

### ⭐ If you find this script helpful, please star the repository! ⭐

```bash
# Show your support:
git clone https://github.com/SumonPaul18/linux-shell-hub.git
# Then ⭐ Star on GitHub!

# Share with your team:
echo "Check out this awesome server setup script: https://github.com/SumonPaul18/linux-shell-hub"
```

**Happy Server Provisioning! 🚀🐧**

</div>

---

> 📌 **Pro Tip:** Bookmark this README and keep a copy of your successful configuration inputs for future server deployments. Consistency is key in infrastructure management! 🔑