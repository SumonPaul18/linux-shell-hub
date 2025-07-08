#!/bin/bash
# This script automates the initial configuration of a new Ubuntu server.
# It includes creating a new user, setting up the hostname, configuring a static IP,
# enabling SSH, installing necessary packages, and setting the timezone.

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as the root user."
  exit 1
fi

# Load configuration file
CONFIG_FILE="config.env"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
  echo "Configuration data loaded from '$CONFIG_FILE'."
else
  echo "Error: '$CONFIG_FILE' file not found. Please create it for server configuration."
  exit 1
fi

echo "--- Starting new server configuration ---"

# Function to display messages with timestamp
log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Check for essential commands
log_message "Checking for essential commands..."
for cmd in ip hostnamectl useradd chpasswd usermod apt systemctl netplan ufw dpkg grep cut sed timedatectl; do
  if ! command -v "$cmd" &>/dev/null; then
    log_message "Error: Command '$cmd' not found. Please ensure it is installed and in your PATH."
    exit 1
  fi
done
log_message "Essential commands found."

# 0. Initial system update and upgrade
log_message "Performing initial system update and upgrade..."
if apt update -y && apt upgrade -y; then
    log_message "System updated and upgraded successfully."
else
    log_message "Warning: Failed to update or upgrade the system. Continuing with setup, but manual intervention might be needed."
fi

# 1. Create a new user and grant admin/sudo permissions
log_message "Creating new user '$NEW_USERNAME' and granting sudo permissions..."
if id "$NEW_USERNAME" &>/dev/null; then
    log_message "User '$NEW_USERNAME' already exists. Skipping user creation."
else
    if useradd -m -s /bin/bash "$NEW_USERNAME"; then
        log_message "User '$NEW_USERNAME' created successfully."
        if echo "$NEW_USERNAME:$NEW_USER_PASSWORD" | chpasswd; then
            log_message "Password set for user '$NEW_USERNAME'."
            if usermod -aG sudo "$NEW_USERNAME"; then
                log_message "Sudo permissions granted to user '$NEW_USERNAME'."
            else
                log_message "Error: Failed to grant sudo permissions to user '$NEW_USERNAME'."
            fi
        else
            log_message "Error: Failed to set password for user '$NEW_USERNAME'."
        fi
    else
        log_message "Error: Failed to create user '$NEW_USERNAME'."
    fi
fi

# 2. Set up the hostname
log_message "Setting hostname to '$SERVER_HOSTNAME'..."
if hostnamectl set-hostname "$SERVER_HOSTNAME"; then
    log_message "Hostname set successfully."
    # Update /etc/hostname file (may be required for some systems)
    if echo "$SERVER_HOSTNAME" > /etc/hostname; then
        log_message "/etc/hostname file updated."
    else
        log_message "Warning: Failed to update /etc/hostname file. Manual check recommended."
    fi
else
    log_message "Error: Failed to set hostname. Manual intervention might be needed."
fi

# 3. Configure Timezone
log_message "Setting timezone to '$TIMEZONE'..."
if timedatectl set-timezone "$TIMEZONE"; then
    log_message "Timezone set successfully to '$TIMEZONE'."
    log_message "Current system time: $(timedatectl status | grep 'Local time' | awk '{print $3, $4, $5}')"
else
    log_message "Error: Failed to set timezone to '$TIMEZONE'. Please check if the timezone is valid using 'timedatectl list-timezones'."
fi

# 4. Determine the primary network interface
log_message "Determining the primary network interface..."
if [ -z "$NETWORK_INTERFACE" ]; then
    log_message "NETWORK_INTERFACE not specified in config.env. Attempting auto-detection."
    # Get the interface connected to the default route, excluding loopback and virtual interfaces
    # This command tries to find the interface that handles traffic to an external IP (like Google's DNS)
    DETECTED_INTERFACE=$(ip -o route get to 8.8.8.8 | awk '{print $5}' | head -n 1)

    if [ -z "$DETECTED_INTERFACE" ]; then
        log_message "Error: Could not automatically detect a network interface. Please check network connectivity or explicitly specify NETWORK_INTERFACE in config.env."
        exit 1
    else
        NETWORK_INTERFACE="$DETECTED_INTERFACE"
        log_message "Auto-detected network interface: '$NETWORK_INTERFACE'."
    fi
else
    log_message "Using specified network interface from config.env: '$NETWORK_INTERFACE'."
    # Validate if the specified interface exists
    if ! ip link show "$NETWORK_INTERFACE" &>/dev/null; then
        log_message "Error: Specified NETWORK_INTERFACE '$NETWORK_INTERFACE' does not exist. Please check config.env."
        exit 1
    fi
fi

# 5. Update /etc/hosts file
log_message "Updating /etc/hosts file..."
# Extract just the IP address from STATIC_IP_CIDR
STATIC_IP=$(echo "$STATIC_IP_CIDR" | cut -d'/' -f1)

# Construct the HOSTS_ENTRIES dynamically using SERVER_HOSTNAME, STATIC_IP, and DOMAIN
HOSTS_ENTRIES="$STATIC_IP $SERVER_HOSTNAME $SERVER_HOSTNAME.$DOMAIN"

# If the hostname entry is not already present, add the new entry.
if ! grep -q "$SERVER_HOSTNAME" /etc/hosts; then
    if echo "$HOSTS_ENTRIES" >> /etc/hosts; then
        log_message "/etc/hosts file updated with new entry: '$HOSTS_ENTRIES'."
    else
        log_message "Error: Failed to update /etc/hosts file. Manual check recommended."
    fi
else
    log_message "Hostname '$SERVER_HOSTNAME' already found in /etc/hosts file. Skipping hosts file update."
fi

# 6. Configure static IP for the network interface (using Netplan)
log_message "Configuring static IP for network interface '$NETWORK_INTERFACE' using Netplan..."
NETPLAN_CONFIG_DIR="/etc/netplan"
NETPLAN_CONFIG_FILE="$NETPLAN_CONFIG_DIR/01-netcfg.yaml"

# Create Netplan configuration directory if it doesn't exist
mkdir -p "$NETPLAN_CONFIG_DIR"

# Backup existing Netplan configuration file if it exists
if [ -f "$NETPLAN_CONFIG_FILE" ]; then
    if mv "$NETPLAN_CONFIG_FILE" "${NETPLAN_CONFIG_FILE}.bak"; then
        log_message "Existing Netplan configuration backed up to '${NETPLAN_CONFIG_FILE}.bak'."
    else
        log_message "Warning: Failed to backup existing Netplan configuration. Manual backup recommended."
    fi
fi

# Create new Netplan configuration file
if cat <<EOF > "$NETPLAN_CONFIG_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $NETWORK_INTERFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP_CIDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$(echo $DNS_SERVERS | sed 's/,/,\ /g')]
EOF
then
    log_message "New Netplan configuration file created: '$NETPLAN_CONFIG_FILE'."
else
    log_message "Error: Failed to create Netplan configuration file. Manual intervention might be needed."
fi

# Apply Netplan configuration
log_message "Applying Netplan configuration..."
if netplan apply; then
    log_message "Static IP configuration applied successfully."
    log_message "Verifying network configuration..."
    # Give a short delay for network changes to propagate
    sleep 2
    ip a show "$NETWORK_INTERFACE" | grep -q "$STATIC_IP"
    if [ $? -eq 0 ]; then
        log_message "IP address '$STATIC_IP' successfully configured on '$NETWORK_INTERFACE'."
    else
        log_message "Warning: Expected IP address not found on network interface '$NETWORK_INTERFACE' after applying Netplan configuration. Manual verification recommended."
    fi
else
    log_message "Error: Failed to apply static IP configuration. Please check logs and review the Netplan configuration file."
fi

# 7. Prepare for remote SSH connection
log_message "Installing and enabling SSH server..."
if ! dpkg -s openssh-server &>/dev/null; then
  log_message "Installing openssh-server..."
  if apt update -y && apt install -y openssh-server; then
    log_message "openssh-server installed successfully."
  else
    log_message "Error: Failed to install openssh-server. Manual installation might be needed."
  fi
else
  log_message "openssh-server is already installed."
fi

if systemctl enable ssh && systemctl start ssh; then
    log_message "SSH server enabled and running."
else
    log_message "Error: Failed to enable or start SSH server. Manual intervention might be needed."
fi

# If UFW (Uncomplicated Firewall) is active, open SSH port
log_message "Checking UFW firewall configuration..."
if systemctl is-active --quiet ufw; then
    log_message "UFW firewall is active. Opening SSH port (22)..."
    if ufw allow ssh && ufw reload; then
        log_message "UFW successfully updated to allow SSH."
    else
        log_message "Error: Failed to update UFW firewall. Manual configuration might be needed."
    fi
else
    log_message "UFW firewall is not active or installed. Skipping SSH port opening in UFW."
fi

# 8. Install necessary software packages
log_message "Installing necessary software packages..."
# apt update was already done at the beginning, but doing it again before installing packages is safer
# if apt update -y; then
#     log_message "Package list updated."
# else
#     log_message "Warning: Failed to update package list."
# fi

for pkg in $PACKAGES_TO_INSTALL; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    log_message "Installing: $pkg..."
    if apt install -y "$pkg"; then
      log_message "$pkg installed successfully."
    else
      log_message "Error: Failed to install $pkg. Manual installation might be needed."
    fi
  else
    log_message "$pkg is already installed. Skipping."
  fi
done
log_message "Software package installation completed."

# 9. Prepare for connection with Ansible control node
log_message "Preparing the server to be managed by an Ansible control node."
log_message "Ensure Python3 is installed (python3-pip package covers this)."
log_message "Ensure the new user ($NEW_USERNAME) has sudo permissions (already configured)."
log_message "Ensure SSH is accessible (already configured)."
log_message "Your new server is now ready to join the infrastructure and be managed by Ansible."

echo "--- New server configuration completed ---"
log_message "Configuration completed. You can now connect to the server via SSH using user '$NEW_USERNAME' and its password."
log_message "Server IP Address: $STATIC_IP"
log_message "Hostname: $SERVER_HOSTNAME"
log_message "Fully Qualified Domain Name (FQDN): $SERVER_HOSTNAME.$DOMAIN"

log_message "Important Security Note: The password is saved in plain text in 'config.env' file. In production environments, this is a security risk. For more secure methods, consider using SSH key-based authentication and disabling password authentication."
