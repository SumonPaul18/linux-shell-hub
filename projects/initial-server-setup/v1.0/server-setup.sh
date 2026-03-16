#!/bin/bash
# =============================================================================
# Script: setup-prod-server.sh
# Version: 3.0 (Hybrid Auth & Ansible Ready)
# Description: Production-ready Ubuntu setup with flexible Auth (Key/Pass/Both)
#              Prepares server specifically for Ansible automation.
# =============================================================================

set -e # Exit immediately if a command exits with a non-zero status

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Helper Functions ---
log() { echo -e "${GREEN}[$(date +'%F %T')]${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then 
    error "Please run this script as root (sudo su -)"
fi

# --- Load Configuration ---
CONFIG_FILE="config.env"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log "Configuration loaded from $CONFIG_FILE"
else
    error "Configuration file '$CONFIG_FILE' not found!"
fi

# Validate Essential Variables
if [ -z "$NEW_USERNAME" ]; then error "NEW_USERNAME is required in config.env"; fi
if [ -z "$STATIC_IP_CIDR" ]; then error "STATIC_IP_CIDR is required in config.env"; fi

# =============================================================================
# 1. System Update & Base Packages (Ansible Prerequisites)
# =============================================================================
log "Updating system and installing base packages..."
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt upgrade -y -qq

# Ensure Python3 is installed (Critical for Ansible)
if ! command -v python3 &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL python3"
fi

apt install -y $PACKAGES_TO_INSTALL
log "System updated and base packages installed."

# =============================================================================
# 2. User Creation & Authentication Setup (Hybrid Logic)
# =============================================================================
log "Configuring user '$NEW_USERNAME' and authentication methods..."

USER_HOME="/home/$NEW_USERNAME"

# Create User if not exists
if ! id "$NEW_USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$NEW_USERNAME"
    log "User '$NEW_USERNAME' created and added to sudo group."
else
    warn "User '$NEW_USERNAME' already exists."
fi

# --- Authentication Logic ---
USE_SSH_KEY=false
USE_PASSWORD=false

# Check SSH Key
if [ -n "$SSH_PUBLIC_KEY" ] && [[ "$SSH_PUBLIC_KEY" == ssh-* ]]; then
    USE_SSH_KEY=true
    mkdir -p "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    
    # Append key if not already present
    if ! grep -q "$SSH_PUBLIC_KEY" "$USER_HOME/.ssh/authorized_keys" 2>/dev/null; then
        echo "$SSH_PUBLIC_KEY" >> "$USER_HOME/.ssh/authorized_keys"
        log "SSH Public Key added to authorized_keys."
    else
        info "SSH Key already present in authorized_keys."
    fi
    chown -R "$NEW_USERNAME:$NEW_USERNAME" "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
fi

# Check Password
if [ -n "$NEW_USER_PASSWORD" ]; then
    USE_PASSWORD=true
    echo "$NEW_USERNAME:$NEW_USER_PASSWORD" | chpasswd
    log "Password set for user '$NEW_USERNAME'."
else
    if [ "$USE_SSH_KEY" = false ]; then
        warn "Neither SSH Key nor Password provided! Generating a temporary random password."
        TEMP_PASS=$(openssl rand -base64 12)
        echo "$NEW_USERNAME:$TEMP_PASS" | chpasswd
        echo -e "${RED}============================================================${NC}"
        echo -e "${RED}⚠️  TEMPORARY PASSWORD GENERATED:${NC}"
        echo -e "${RED}   User: $NEW_USERNAME${NC}"
        echo -e "${RED}   Pass: $TEMP_PASS${NC}"
        echo -e "${RED}   ⚠️  SAVE THIS NOW! It will not be shown again.${NC}"
        echo -e "${RED}============================================================${NC}"
        USE_PASSWORD=true
    fi
fi

# =============================================================================
# 3. SSH Hardening Configuration
# =============================================================================
log "Hardening SSH configuration (/etc/ssh/sshd_config)..."
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_SUFFIX=".bak.$(date +%F-%H%M)"

# Backup original config
cp "$SSHD_CONFIG" "${SSHD_CONFIG}${BACKUP_SUFFIX}"

# Determine Auth Settings based on inputs
PERMIT_ROOT="no"
PASSWORD_AUTH="no"
PUBKEY_AUTH="yes"

if [ "$DISABLE_ROOT_LOGIN" != "yes" ]; then
    PERMIT_ROOT="prohibit-password" # Allow root only with key, safer than 'yes'
    warn "Root login allowed (Key only) as per config."
fi

if [ "$USE_PASSWORD" = true ] && [ "$USE_SSH_KEY" = true ]; then
    PASSWORD_AUTH="yes"
    log "Mode: Hybrid (SSH Key + Password enabled)"
elif [ "$USE_PASSWORD" = true ]; then
    PUBKEY_AUTH="no" # Optional: Disable keys if only password wanted (not recommended for prod)
    log "Mode: Password Only"
elif [ "$USE_SSH_KEY" = true ]; then
    PASSWORD_AUTH="no"
    log "Mode: SSH Key Only (Recommended)"
else
    # Fallback if logic fails
    PASSWORD_AUTH="yes"
    warn "Fallback: Enabling Password Auth due to configuration ambiguity."
fi

# Apply Settings using sed (Idempotent safe)
sed -i "s/^#*PermitRootLogin.*/PermitRootLogin $PERMIT_ROOT/" "$SSHD_CONFIG"
sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication $PASSWORD_AUTH/" "$SSHD_CONFIG"
sed -i "s/^#*PubkeyAuthentication.*/PubkeyAuthentication $PUBKEY_AUTH/" "$SSHD_CONFIG"
sed -i "s/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/" "$SSHD_CONFIG"
sed -i "s/^#*X11Forwarding.*/X11Forwarding no/" "$SSHD_CONFIG"
sed -i "s/^#*ClientAliveInterval.*/ClientAliveInterval 300/" "$SSHD_CONFIG"
sed -i "s/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/" "$SSHD_CONFIG"

# Ensure AllowUsers is set correctly
if ! grep -q "^AllowUsers" "$SSHD_CONFIG"; then
    echo "AllowUsers $NEW_USERNAME" >> "$SSHD_CONFIG"
else
    sed -i "s/^AllowUsers.*/AllowUsers $NEW_USERNAME/" "$SSHD_CONFIG"
fi

# Restart SSH Service
if systemctl restart sshd; then
    log "SSH service restarted successfully with new hardening rules."
else
    error "Failed to restart SSH. Check syntax with 'sshd -t'. Restoring backup..."
    cp "${SSHD_CONFIG}${BACKUP_SUFFIX}" "$SSHD_CONFIG"
    systemctl restart sshd
    exit 1
fi

# =============================================================================
# 4. Network Configuration (Netplan)
# =============================================================================
log "Configuring Static IP via Netplan..."
NETPLAN_DIR="/etc/netplan"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NEW_NETPLAN="$NETPLAN_DIR/01-netcfg.yaml"

# Auto-detect interface if not specified
if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE=$(ip -o route get to 8.8.8.8 | awk '{print $5}' | head -n1)
    if [ -z "$NETWORK_INTERFACE" ]; then
        NETWORK_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n1)
    fi
    log "Auto-detected interface: $NETWORK_INTERFACE"
fi

# Backup existing configs
for f in "$NETPLAN_DIR"/*.yaml; do
    [ -e "$f" ] && mv "$f" "${f}.disabled.${TIMESTAMP}.bak"
done

# Create new config
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

# Apply Netplan
if netplan apply; then
    log "Static IP ($STATIC_IP_CIDR) applied successfully."
else
    error "Netplan apply failed. Check configuration."
fi

# =============================================================================
# 5. Security Tools: UFW & Fail2Ban
# =============================================================================
log "Setting up Firewall (UFW) and Fail2Ban..."

# UFW Setup
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
log "UFW enabled (SSH allowed)."

# Fail2Ban Setup
systemctl enable fail2ban
systemctl start fail2ban
log "Fail2Ban active and protecting SSH."

# =============================================================================
# 6. Ansible Readiness Verification
# =============================================================================
log "Verifying Ansible readiness..."

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VER=$(python3 --version)
    log "✅ $PYTHON_VER found."
else
    error "Python3 not found! Ansible will not work."
fi

# Check Sudo
if sudo -n true 2>/dev/null; then
    log "✅ Sudo access verified for current context."
fi

# =============================================================================
# 7. Final Report & Inventory Snippet
# =============================================================================
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}🎉 PRODUCTION SERVER SETUP COMPLETED!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "👤 User: ${YELLOW}$NEW_USERNAME${NC}"
echo -e "🔐 Auth Mode: ${YELLOW}$([ "$USE_SSH_KEY" = true ] && echo "SSH Key") $([ "$USE_PASSWORD" = true ] && echo "+ Password")${NC}"
echo -e "🌐 IP Address: ${YELLOW}$STATIC_IP${NC}"
echo -e "🏷️  Hostname: ${YELLOW}$SERVER_HOSTNAME${NC}"
echo -e "🛡️  Security: ${YELLOW}UFW Active, Fail2Ban Running, Root Login Disabled${NC}"
echo -e "🤖 Ansible Ready: ${YELLOW}Yes (Python3 + SSH Configured)${NC}"

echo -e "\n${BLUE}📋 COPY THIS TO YOUR ANSIBLE INVENTORY FILE:${NC}"
echo "------------------------------------------------------------"
echo "[production]"
if [ "$USE_SSH_KEY" = true ]; then
    echo "$SERVER_HOSTNAME ansible_host=$STATIC_IP ansible_user=$NEW_USERNAME ansible_ssh_private_key_file=~/.ssh/id_ed25519"
else
    echo "$SERVER_HOSTNAME ansible_host=$STATIC_IP ansible_user=$NEW_USERNAME"
    echo "# Note: You may need to pass password via CLI or vault if not using ssh-agent"
fi
echo "------------------------------------------------------------"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Test SSH connection: ssh $NEW_USERNAME@$STATIC_IP"
echo "2. Add the above snippet to your Ansible inventory.ini"
echo "3. Run: ansible all -i inventory.ini -m ping"
echo -e "============================================================\n"

# Cleanup sensitive data in config if needed (Optional)
# rm -f "$CONFIG_FILE" 
