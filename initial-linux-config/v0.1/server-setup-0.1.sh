#!/bin/bash
# =============================================================================
# Script: setup-server.sh
# Description: Automates initial configuration of a new Ubuntu server
#              - User creation, hostname, static IP (Netplan), SSH, packages
# =============================================================================

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this script as the root user (use 'sudo su' or login as root)."
  exit 1
fi

# Load configuration file
CONFIG_FILE="config.env"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
  echo "✅ Configuration data loaded from '$CONFIG_FILE'."
else
  echo "❌ Error: '$CONFIG_FILE' file not found. Please create it for server configuration."
  exit 1
fi

echo "============================================================"
echo "--- Starting new server configuration ---"
echo "============================================================"

# Function to display messages with timestamp
log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# =============================================================================
# PRE-CHECK: Essential commands validation
# =============================================================================
log_message "Checking for essential commands..."
ESSENTIAL_CMDS="ip hostnamectl useradd chpasswd usermod apt systemctl netplan ufw dpkg grep cut sed awk timedatectl"
for cmd in $ESSENTIAL_CMDS; do
  if ! command -v "$cmd" &>/dev/null; then
    log_message "❌ Error: Command '$cmd' not found. Please ensure it is installed."
    exit 1
  fi
done
log_message "✅ All essential commands found."

# =============================================================================
# 0. Initial system update and upgrade
# =============================================================================
log_message "Performing initial system update and upgrade..."
if apt update -y && apt upgrade -y; then
    log_message "✅ System updated and upgraded successfully."
else
    log_message "⚠️ Warning: Failed to update/upgrade system. Continuing with setup..."
fi

# =============================================================================
# 1. Create new user with sudo permissions
# =============================================================================
log_message "Creating new user '$NEW_USERNAME' with sudo permissions..."
if id "$NEW_USERNAME" &>/dev/null; then
    log_message "⚠️ User '$NEW_USERNAME' already exists. Skipping creation."
else
    if useradd -m -s /bin/bash "$NEW_USERNAME"; then
        log_message "✅ User '$NEW_USERNAME' created."
        if echo "$NEW_USERNAME:$NEW_USER_PASSWORD" | chpasswd; then
            log_message "✅ Password set for '$NEW_USERNAME'."
            if usermod -aG sudo "$NEW_USERNAME"; then
                log_message "✅ Sudo permissions granted to '$NEW_USERNAME'."
            else
                log_message "❌ Error: Failed to grant sudo to '$NEW_USERNAME'."
            fi
        else
            log_message "❌ Error: Failed to set password for '$NEW_USERNAME'."
        fi
    else
        log_message "❌ Error: Failed to create user '$NEW_USERNAME'."
    fi
fi

# =============================================================================
# 2. Set hostname
# =============================================================================
log_message "Setting hostname to '$SERVER_HOSTNAME'..."
if hostnamectl set-hostname "$SERVER_HOSTNAME"; then
    log_message "✅ Hostname set successfully."
    echo "$SERVER_HOSTNAME" > /etc/hostname 2>/dev/null && \
        log_message "✅ /etc/hostname updated." || \
        log_message "⚠️ Warning: Could not update /etc/hostname manually."
else
    log_message "❌ Error: Failed to set hostname via hostnamectl."
fi

# =============================================================================
# 3. Configure Timezone
# =============================================================================
log_message "Setting timezone to '$TIMEZONE'..."
if timedatectl set-timezone "$TIMEZONE" 2>/dev/null; then
    log_message "✅ Timezone set to '$TIMEZONE'."
    log_message "🕐 Current system time: $(timedatectl | grep 'Local time' | awk '{print $3, $4, $5}')"
else
    log_message "❌ Error: Invalid timezone '$TIMEZONE'. Check with 'timedatectl list-timezones'."
fi

# =============================================================================
# 4. Determine primary network interface
# =============================================================================
log_message "Determining primary network interface..."
if [ -z "$NETWORK_INTERFACE" ]; then
    log_message "🔍 NETWORK_INTERFACE not specified. Auto-detecting..."
    DETECTED_INTERFACE=$(ip -o route get to 8.8.8.8 2>/dev/null | awk '{print $5}' | head -n1)
    
    if [ -z "$DETECTED_INTERFACE" ]; then
        # Fallback: get first non-lo interface
        DETECTED_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n1)
    fi
    
    if [ -z "$DETECTED_INTERFACE" ]; then
        log_message "❌ Error: Could not auto-detect network interface. Specify NETWORK_INTERFACE in config.env"
        exit 1
    else
        NETWORK_INTERFACE="$DETECTED_INTERFACE"
        log_message "✅ Auto-detected interface: '$NETWORK_INTERFACE'"
    fi
else
    log_message "✅ Using specified interface from config.env: '$NETWORK_INTERFACE'"
    if ! ip link show "$NETWORK_INTERFACE" &>/dev/null; then
        log_message "❌ Error: Interface '$NETWORK_INTERFACE' does not exist. Check config.env"
        exit 1
    fi
fi

# =============================================================================
# 5. Update /etc/hosts file
# =============================================================================
log_message "Updating /etc/hosts file..."
STATIC_IP=$(echo "$STATIC_IP_CIDR" | cut -d'/' -f1)
HOSTS_ENTRY="$STATIC_IP $SERVER_HOSTNAME $SERVER_HOSTNAME.$DOMAIN"

if ! grep -q "$SERVER_HOSTNAME" /etc/hosts 2>/dev/null; then
    echo "$HOSTS_ENTRY" >> /etc/hosts && \
        log_message "✅ Added to /etc/hosts: $HOSTS_ENTRY" || \
        log_message "❌ Error: Failed to update /etc/hosts"
else
    log_message "⚠️ Hostname '$SERVER_HOSTNAME' already in /etc/hosts. Skipping."
fi

# =============================================================================
# 6. Configure Static IP via Netplan (BACKUP ALL YAML, DISABLE DHCP)
# =============================================================================
log_message "Configuring Static IP via Netplan for interface '$NETWORK_INTERFACE'..."
NETPLAN_DIR="/etc/netplan"
NEW_NETPLAN_FILE="$NETPLAN_DIR/01-netcfg.yaml"
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$NETPLAN_DIR"

# 🔥 CRITICAL: Backup ALL existing .yaml files in /etc/netplan/
log_message "🔄 Backing up ALL existing Netplan .yaml files..."
YAML_FILES_FOUND=0
for yaml_file in "$NETPLAN_DIR"/*.yaml; do
    # Skip if no files match (glob returns literal string)
    [ -e "$yaml_file" ] || continue
    
    filename=$(basename "$yaml_file")
    backup_name="${filename}.disabled.${BACKUP_TIMESTAMP}.bak"
    
    if mv "$yaml_file" "$NETPLAN_DIR/$backup_name"; then
        log_message "✅ Backed up: '$filename' → '$backup_name'"
        ((YAML_FILES_FOUND++))
    else
        log_message "❌ Warning: Failed to backup '$yaml_file'"
    fi
done

if [ "$YAML_FILES_FOUND" -eq 0 ]; then
    log_message "ℹ️ No existing .yaml files found in $NETPLAN_DIR. Creating fresh config."
fi

# Create new Netplan configuration with Static IP (DHCP fully disabled)
log_message "📝 Creating new Netplan config: '$NEW_NETPLAN_FILE'..."
cat <<EOF > "$NEW_NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $NETWORK_INTERFACE:
      dhcp4: no
      dhcp6: no
      addresses:
        - $STATIC_IP_CIDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$(echo "$DNS_SERVERS" | sed 's/,/, /g')]
      optional: true
      link-local: []
EOF

if [ $? -eq 0 ]; then
    log_message "✅ Netplan config file created."
    # Set secure permissions
    chmod 600 "$NEW_NETPLAN_FILE"
    log_message "🔐 Set permissions 600 for Netplan config."
else
    log_message "❌ Error: Failed to create Netplan config file."
    exit 1
fi

# Apply Netplan configuration with error handling
log_message "⚙️ Applying Netplan configuration..."
if netplan --debug apply 2>&1 | tee /tmp/netplan_apply.log; then
    log_message "✅ Netplan applied successfully."
    sleep 3
    
    # Verify IP configuration
    log_message "🔍 Verifying IP configuration..."
    if ip -4 addr show "$NETWORK_INTERFACE" | grep -q "$STATIC_IP"; then
        log_message "✅ Static IP '$STATIC_IP' is active on '$NETWORK_INTERFACE'"
    else
        log_message "⚠️ Warning: Static IP not immediately visible. Forcing DHCP release..."
        # Release any stale DHCP lease
        if command -v dhclient &>/dev/null; then
            dhclient -r "$NETWORK_INTERFACE" 2>/dev/null || true
            sleep 2
        fi
        netplan apply
        sleep 2
        if ip -4 addr show "$NETWORK_INTERFACE" | grep -q "$STATIC_IP"; then
            log_message "✅ Static IP '$STATIC_IP' confirmed after DHCP release."
        else
            log_message "❌ Error: Static IP still not active. Check: /tmp/netplan_apply.log"
        fi
    fi
else
    log_message "❌ Error: Netplan apply failed."
    log_message "📄 Check debug log: /tmp/netplan_apply.log"
    # Attempt rollback: restore first backup if exists
    FIRST_BACKUP=$(ls -t "$NETPLAN_DIR"/*.bak 2>/dev/null | head -n1)
    if [ -n "$FIRST_BACKUP" ]; then
        log_message "🔄 Attempting rollback: restoring $FIRST_BACKUP"
        cp "$FIRST_BACKUP" "$NEW_NETPLAN_FILE" 2>/dev/null && netplan apply
    fi
    exit 1
fi

# =============================================================================
# 7. Install and Configure SSH Server
# =============================================================================
log_message "🔐 Configuring SSH server..."
if ! dpkg -s openssh-server &>/dev/null; then
    log_message "📦 Installing openssh-server..."
    apt install -y openssh-server || log_message "⚠️ Warning: openssh-server installation failed"
else
    log_message "✅ openssh-server already installed."
fi

if systemctl enable ssh && systemctl start ssh; then
    log_message "✅ SSH service enabled and running."
else
    log_message "❌ Error: Failed to start SSH service."
fi

# Configure UFW firewall if active
if systemctl is-active --quiet ufw 2>/dev/null; then
    log_message "🛡️ UFW is active. Opening SSH port (22)..."
    ufw allow ssh >/dev/null 2>&1 && ufw reload >/dev/null 2>&1 && \
        log_message "✅ UFW: SSH port opened." || \
        log_message "⚠️ Warning: Could not update UFW rules."
else
    log_message "ℹ️ UFW not active. Skipping firewall config."
fi

# =============================================================================
# 8. Install Required Packages
# =============================================================================
log_message "📦 Installing required packages: $PACKAGES_TO_INSTALL"
apt update -y >/dev/null 2>&1

for pkg in $PACKAGES_TO_INSTALL; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        log_message "🔄 Installing: $pkg..."
        if apt install -y "$pkg" >/dev/null 2>&1; then
            log_message "✅ $pkg installed."
        else
            log_message "❌ Failed to install: $pkg"
        fi
    else
        log_message "✅ $pkg already installed. Skipping."
    fi
done
log_message "🎉 Package installation completed."

# =============================================================================
# 9. Cleanup: Release any stale DHCP leases
# =============================================================================
log_message "🧹 Cleaning up network state..."
if command -v dhclient &>/dev/null; then
    # Kill any running dhclient for this interface
    pkill -f "dhclient.*$NETWORK_INTERFACE" 2>/dev/null || true
    dhclient -r "$NETWORK_INTERFACE" 2>/dev/null || true
    log_message "✅ DHCP client stopped for '$NETWORK_INTERFACE'"
fi

# Restart network renderer to ensure clean state
if systemctl is-active --quiet systemd-networkd; then
    systemctl restart systemd-networkd 2>/dev/null && \
        log_message "✅ systemd-networkd restarted." || \
        log_message "⚠️ Warning: Could not restart systemd-networkd"
fi

# =============================================================================
# 10. Final Summary & Ansible Preparation
# =============================================================================
echo ""
echo "============================================================"
echo "🎉 SERVER CONFIGURATION COMPLETED SUCCESSFULLY!"
echo "============================================================"
log_message "👤 New User: $NEW_USERNAME (with sudo)"
log_message "🌐 Server IP: $STATIC_IP"
log_message "🏷️  Hostname: $SERVER_HOSTNAME"
log_message "🌍 FQDN: $SERVER_HOSTNAME.$DOMAIN"
log_message "🔌 SSH: Enabled on port 22"
log_message "📦 Packages: $PACKAGES_TO_INSTALL"
log_message "🕐 Timezone: $TIMEZONE"
echo ""
log_message "🔑 You can now SSH as: ssh $NEW_USERNAME@$STATIC_IP"
log_message "⚙️  Server is ready for Ansible management!"
echo ""
log_message "🔐 SECURITY REMINDER:"
log_message "   - Password is stored in plain text in 'config.env'"
log_message "   - For production: Use SSH keys + disable password auth"
log_message "   - Run: ssh-keygen && ssh-copy-id $NEW_USERNAME@$STATIC_IP"
echo "============================================================"

exit 0
