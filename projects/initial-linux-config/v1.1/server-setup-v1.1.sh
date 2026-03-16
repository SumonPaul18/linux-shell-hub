#!/bin/bash
# =============================================================================
# Script: setup-prod-server.sh
# Version: 4.0 (Fully Configurable & Ansible Ready)
# Description: Advanced Ubuntu setup with dynamic Auth, Granular SSH Hardening,
#              Toggleable Security Tools, and Passwordless Sudo support.
# =============================================================================

set -e # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper Functions
log() { echo -e "${GREEN}[$(date +'%F %T')]${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Root Check
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (sudo su -)"
fi

# Load Configuration
CONFIG_FILE="config.env"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log "Configuration loaded from $CONFIG_FILE"
else
    error "Configuration file '$CONFIG_FILE' not found!"
fi

# Validate Essentials
[ -z "$NEW_USERNAME" ] && error "NEW_USERNAME is required."
[ -z "$STATIC_IP_CIDR" ] && error "STATIC_IP_CIDR is required."

# =============================================================================
# 1. System Update & Base Packages
# =============================================================================
log "Updating system and installing base packages..."
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt upgrade -y -qq

# Ensure Python3 for Ansible
if ! command -v python3 &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL python3"
fi

apt install -y $PACKAGES_TO_INSTALL
log "System updated and packages installed."

# =============================================================================
# 2. User Creation & Authentication Logic
# =============================================================================
log "Configuring user '$NEW_USERNAME'..."
USER_HOME="/home/$NEW_USERNAME"

# Create User
if ! id "$NEW_USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$NEW_USERNAME"
    log "User created and added to sudo group."
else
    warn "User already exists."
fi

# Determine Auth Mode
USE_SSH_KEY=false
USE_PASSWORD=false

# Check SSH Key
if [ -n "$SSH_PUBLIC_KEY" ] && [[ "$SSH_PUBLIC_KEY" == ssh-* ]]; then
    USE_SSH_KEY=true
    mkdir -p "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    if ! grep -q "$SSH_PUBLIC_KEY" "$USER_HOME/.ssh/authorized_keys" 2>/dev/null; then
        echo "$SSH_PUBLIC_KEY" >> "$USER_HOME/.ssh/authorized_keys"
        log "SSH Public Key added."
    else
        info "SSH Key already present."
    fi
    chown -R "$NEW_USERNAME:$NEW_USERNAME" "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
fi

# Check Password
if [ -n "$NEW_USER_PASSWORD" ]; then
    USE_PASSWORD=true
    echo "$NEW_USERNAME:$NEW_USER_PASSWORD" | chpasswd
    log "Password set."
else
    if [ "$USE_SSH_KEY" = false ]; then
        warn "No Key or Password provided. Generating random password."
        TEMP_PASS=$(openssl rand -base64 12)
        echo "$NEW_USERNAME:$TEMP_PASS" | chpasswd
        echo -e "${RED}⚠️  TEMP PASSWORD: $TEMP_PASS (Save it!)${NC}"
        USE_PASSWORD=true
    else
        info "No password set (SSH Key mode)."
    fi
fi

# Configure Sudo (Passwordless or Standard)
SUDO_CONF="/etc/sudoers.d/$NEW_USERNAME"
if [ "$PASSWORDLESS_SUDO" = "yes" ]; then
    echo "$NEW_USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDO_CONF"
    chmod 440 "$SUDO_CONF"
    log "Passwordless Sudo enabled for $NEW_USERNAME."
else
    # Ensure standard sudo (group membership usually handles this, but explicit is safe)
    echo "$NEW_USERNAME ALL=(ALL) ALL" > "$SUDO_CONF"
    chmod 440 "$SUDO_CONF"
    log "Standard Sudo (password required) enabled for $NEW_USERNAME."
fi

# =============================================================================
# 3. Dynamic SSH Hardening
# =============================================================================
log "Applying SSH Hardening configurations..."
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_SUFFIX=".bak.$(date +%F-%H%M)"

cp "$SSHD_CONFIG" "${SSHD_CONFIG}${BACKUP_SUFFIX}"

# Logic Overrides for Security Consistency
FINAL_PASS_AUTH="$SSH_PASSWORD_AUTHENTICATION"
FINAL_ROOT_LOGIN="$SSH_PERMIT_ROOT_LOGIN"

# Override: If no password is set for user, force PasswordAuthentication no
if [ "$USE_PASSWORD" = false ]; then
    FINAL_PASS_AUTH="no"
    warn "Forcing PasswordAuthentication=no (No user password set)."
fi

# Override: If Pubkey is no and Pass is no, warn (Lockout risk)
if [ "$SSH_PUBKEY_AUTHENTICATION" = "no" ] && [ "$FINAL_PASS_AUTH" = "no" ]; then
    error "CRITICAL: Both SSH Key and Password auth are disabled. You will be locked out!"
fi

# Apply Settings via sed
declare -A SSH_SETTINGS=(
    ["PermitRootLogin"]="$FINAL_ROOT_LOGIN"
    ["PasswordAuthentication"]="$FINAL_PASS_AUTH"
    ["PubkeyAuthentication"]="$SSH_PUBKEY_AUTHENTICATION"
    ["PermitEmptyPasswords"]="$SSH_PERMIT_EMPTY_PASSWORDS"
    ["X11Forwarding"]="$SSH_X11_FORWARDING"
    ["ClientAliveInterval"]="$SSH_CLIENT_ALIVE_INTERVAL"
    ["ClientAliveCountMax"]="$SSH_CLIENT_ALIVE_COUNT_MAX"
    ["MaxAuthTries"]="$SSH_MAX_AUTH_TRIES"
)

for key in "${!SSH_SETTINGS[@]}"; do
    val="${SSH_SETTINGS[$key]}"
    # Remove comments and replace value
    sed -i "s/^#*$key.*/$key $val/" "$SSHD_CONFIG"
    # If line didn't exist (unlikely in default ubuntu), append it
    if ! grep -q "^$key" "$SSHD_CONFIG"; then
        echo "$key $val" >> "$SSHD_CONFIG"
    fi
done

# AllowUsers Directive
if ! grep -q "^AllowUsers" "$SSHD_CONFIG"; then
    echo "AllowUsers $NEW_USERNAME" >> "$SSHD_CONFIG"
else
    sed -i "s/^AllowUsers.*/AllowUsers $NEW_USERNAME/" "$SSHD_CONFIG"
fi

# Restart SSH
if systemctl restart sshd; then
    log "SSH restarted with hardening rules."
else
    error "SSH restart failed. Restoring backup..."
    cp "${SSHD_CONFIG}${BACKUP_SUFFIX}" "$SSHD_CONFIG"
    systemctl restart sshd
    exit 1
fi

# =============================================================================
# 4. Network Configuration (Netplan)
# =============================================================================
log "Configuring Static IP..."
NETPLAN_DIR="/etc/netplan"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NEW_NETPLAN="$NETPLAN_DIR/01-netcfg.yaml"

# Auto-detect Interface
if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE=$(ip -o route get to 8.8.8.8 | awk '{print $5}' | head -n1)
    [ -z "$NETWORK_INTERFACE" ] && NETWORK_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n1)
    log "Auto-detected interface: $NETWORK_INTERFACE"
fi

# Backup & Create
for f in "$NETPLAN_DIR"/*.yaml; do [ -e "$f" ] && mv "$f" "${f}.disabled.${TIMESTAMP}.bak"; done

cat <<EOF > "$NEW_NETPLAN"
network:
  version: 2
  renderer: networkd
  ethernets:
    $NETWORK_INTERFACE:
      dhcp4: no
      dhcp6: no
      addresses: [$STATIC_IP_CIDR]
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$(echo "$DNS_SERVERS" | sed 's/,/, /g')]
      optional: true
EOF

chmod 600 "$NEW_NETPLAN"
netplan apply && log "Static IP applied." || error "Netplan apply failed."

# =============================================================================
# 5. Security Tools (UFW & Fail2Ban)
# =============================================================================
if [ "$ENABLE_UFW" = "yes" ]; then
    log "Enabling UFW Firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw --force enable
    log "UFW Enabled."
else
    warn "UFW Firewall skipped (Disabled in config)."
fi

if [ "$ENABLE_FAIL2BAN" = "yes" ]; then
    log "Enabling Fail2Ban..."
    apt install -y fail2ban >/dev/null 2>&1
    systemctl enable fail2ban
    systemctl start fail2ban
    log "Fail2Ban Enabled."
else
    warn "Fail2Ban skipped (Disabled in config)."
fi

# =============================================================================
# 6. Final Report & Ansible Inventory
# =============================================================================
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}🎉 SERVER SETUP COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "👤 User: ${YELLOW}$NEW_USERNAME${NC}"
echo -e "🔐 Sudo: ${YELLOW}$([ "$PASSWORDLESS_SUDO" = "yes" ] && echo "Passwordless" || echo "Standard")${NC}"
echo -e "🔑 Auth: ${YELLOW}$([ "$USE_SSH_KEY" = true ] && echo "SSH Key") $([ "$USE_PASSWORD" = true ] && echo "+ Password")${NC}"
echo -e "🌐 IP: ${YELLOW}$STATIC_IP${NC}"
echo -e "🛡️  UFW: ${YELLOW}$([ "$ENABLE_UFW" = "yes" ] && echo "Active" || echo "Disabled")${NC}"
echo -e "🚫 Fail2Ban: ${YELLOW}$([ "$ENABLE_FAIL2BAN" = "yes" ] && echo "Active" || echo "Disabled")${NC}"
echo -e "🤖 Ansible Ready: ${YELLOW}Yes${NC}"

echo -e "\n${BLUE}📋 COPY THIS TO YOUR ANSIBLE INVENTORY:${NC}"
echo "------------------------------------------------------------"
echo "[production]"
INV_LINE="$SERVER_HOSTNAME ansible_host=$STATIC_IP ansible_user=$NEW_USERNAME"
if [ "$USE_SSH_KEY" = true ]; then
    INV_LINE="$INV_LINE ansible_ssh_private_key_file=~/.ssh/id_ed25519"
fi
if [ "$PASSWORDLESS_SUDO" = "yes" ]; then
    INV_LINE="$INV_LINE ansible_become=yes ansible_become_method=sudo"
else
    INV_LINE="$INV_LINE ansible_become=yes ansible_become_pass='YOUR_PASSWORD'"
fi
echo "$INV_LINE"
echo "------------------------------------------------------------"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Test SSH: ssh $NEW_USERNAME@$STATIC_IP"
echo "2. Add snippet to inventory.ini"
echo "3. Run: ansible all -i inventory.ini -m ping"
echo -e "============================================================\n"