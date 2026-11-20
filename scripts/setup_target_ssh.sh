#!/bin/bash

# This script is designed to be run on the target machine (192.168.0.94)
# to enable SSH, configure it for Ansible, and set up essential services.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. Basic System Updates and Essential Tools ---
echo "--- 1. Updating system and installing essential tools ---"
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openssh-server net-tools curl wget git htop vim

# --- 2. Enable and Start SSH Service ---
echo "--- 2. Enabling and starting SSH service ---"
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl status ssh | grep "Active"

# --- 3. Configure UFW (Uncomplicated Firewall) ---
# Allow SSH and potentially other necessary ports.
# If you have a different firewall, adjust accordingly.
echo "--- 3. Configuring UFW firewall ---"
sudo ufw allow OpenSSH
# If you plan to run web services (e.g., Apache, Nginx) later, you might want to allow these:
# sudo ufw allow 'Apache Full'
# sudo ufw allow 'Nginx Full'
# If you need specific ports for other services, add them here (e.g., for a database):
# sudo ufw allow 5432/tcp # Example for PostgreSQL
#sudo ufw enable
sudo ufw status verbose

# --- 4. SSH Configuration for Ansible (Passwordless SSH) ---
# This assumes you will generate an SSH key on your Ansible control node (192.168.0.93)
# and copy the public key to 192.168.0.94.
# This part of the script prepares the target for key-based authentication.

echo "--- 4. Preparing for SSH key-based authentication for Ansible ---"

# Create .ssh directory if it doesn't exist and set correct permissions
if [ ! -d "/home/cloud3/.ssh" ]; then
    mkdir -p /home/cloud3/.ssh
    chmod 700 /home/cloud3/.ssh
    chown cloud3:cloud3 /home/cloud3/.ssh
fi

# Ensure authorized_keys file exists and has correct permissions
if [ ! -f "/home/cloud3/.ssh/authorized_keys" ]; then
    touch /home/cloud3/.ssh/authorized_keys
    chmod 600 /home/cloud3/.ssh/authorized_keys
    chown cloud3:cloud3 /home/cloud3/.ssh/authorized_keys
fi

# Recommended SSH server security settings (optional but good practice)
# Make a backup of the original sshd_config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Modify sshd_config to enhance security and allow necessary options for Ansible
# Using 'sudo tee -a' to append or 'sudo sed -i' for in-place editing
echo "--- 4.1 Modifying SSHD configuration for security and Ansible compatibility ---"
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#UsePAM yes/UsePAM no/' /etc/ssh/sshd_config # May need to be 'yes' for some setups, 'no' is common for Ansible
sudo sed -i 's/#AllowAgentForwarding yes/AllowAgentForwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/#X11Forwarding yes/X11Forwarding yes/' /etc/ssh/sshd_config

# Ensure these lines exist or add them if they don't, especially for Ansible:
if ! grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
fi
if ! grep -q "AuthorizedKeysFile	.ssh/authorized_keys" /etc/ssh/sshd_config; then
    echo "AuthorizedKeysFile	.ssh/authorized_keys" | sudo tee -a /etc/ssh/sshd_config
fi

# Restart SSH service to apply changes
echo "--- 4.2 Restarting SSH service after configuration changes ---"
sudo systemctl restart ssh

# --- 5. User Management (if 'cloud3' user doesn't exist or needs sudo access) ---
# Assuming 'cloud3' user already exists as per your prompt.
# If not, you might need to create it and grant sudo permissions.
echo "--- 5. Verifying 'cloud3' user and sudo permissions ---"
if id "cloud3" &>/dev/null; then
    echo "User 'cloud3' already exists."
else
    echo "User 'cloud3' does not exist. Creating user..."
    sudo adduser cloud3 --gecos "Cloud User,,,," --disabled-password
    echo "cloud3:your_temporary_password" | sudo chpasswd # Set a temporary password, user should change it later
fi

# Grant sudo access to 'cloud3' without requiring a password for Ansible
# This is a common practice for Ansible managed nodes.
# Be very careful with this in production environments.
echo "--- 5.1 Granting 'cloud3' sudo access without password ---"
echo "cloud3 ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/cloud3_nopasswd > /dev/null
sudo chmod 0440 /etc/sudoers.d/cloud3_nopasswd

# --- 6. Network Configuration Check (Optional but good for troubleshooting) ---
echo "--- 6. Verifying network configuration ---"
ip a show | grep "inet "
ping -c 3 192.168.0.93 # Ping back to the source machine to ensure connectivity

echo "--- Script execution completed on 192.168.0.94 ---"
echo "You should now be able to SSH from 192.168.0.93 to 192.168.0.94."
echo "Remember to copy your SSH public key from 192.168.0.93 to 192.168.0.94:"
echo "ssh-copy-id cloud3@192.168.0.94"
echo "Or manually: ssh cloud3@192.168.0.94 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' < ~/.ssh/id_rsa.pub"
echo "Then test: ssh cloud3@192.168.0.94"
