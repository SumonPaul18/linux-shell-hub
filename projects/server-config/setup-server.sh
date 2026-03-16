#!/bin/bash

###############################################################################
# Universal Linux Server Preparation Script v3.0
# Features: 
# - Clean output (No DEBUG noise)
# - Backups stored in /etc/netplan/backup/
# - Pre-validation with netplan generate
# - All interfaces get 3 options (No-IP/Static/DHCP)
# - Clean IP in /etc/hosts (no CIDR prefix)
# Supported: Ubuntu/Debian, CentOS/AlmaLinux/RHEL
###############################################################################

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
silent_run() { "$@" > /dev/null 2>&1; }

# Check Root Privileges
if [ "$EUID" -ne 0 ]; then
  log_error "Please run as root (sudo ./script.sh)"
  exit 1
fi

# 1. OS Detection
log_step "System Detection"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_LIKE=$ID_LIKE
else
    log_error "Cannot detect OS. Exiting."
    exit 1
fi

PKG_MGR=""
NET_CONFIG_METHOD=""
FIREWALL_SERVICE=""

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]; then
    PKG_MGR="apt"
    NET_CONFIG_METHOD="netplan"
    FIREWALL_SERVICE="ufw"
    log_info "Detected: Debian/Ubuntu Family (apt + netplan)"
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "almalinux" || "$OS_ID" == "rhel" || "$OS_LIKE" == *"rhel"* ]]; then
    PKG_MGR="dnf"
    NET_CONFIG_METHOD="nmcli"
    FIREWALL_SERVICE="firewalld"
    command -v dnf &> /dev/null || PKG_MGR="yum"
    log_info "Detected: RHEL/CentOS Family (dnf/yum + NetworkManager)"
else
    log_warn "Unknown OS. Trying generic config..."
    PKG_MGR="apt"
    NET_CONFIG_METHOD="netplan"
    FIREWALL_SERVICE="ufw"
fi

# 2. System Inputs
log_step "Basic Configuration"
read -p "Enter Hostname (e.g., controller): " HOSTNAME
read -p "Enter FQDN (e.g., controller.paulco.xyz): " FQDN

# 3. Network Interface Detection
log_step "Network Interface Detection"
mapfile -t INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | sort)

if [ ${#INTERFACES[@]} -eq 0 ]; then
    log_error "No network interfaces found!"
    exit 1
fi

log_info "Found ${#INTERFACES[@]} interface(s): ${INTERFACES[*]}"

# Arrays for config storage
declare -A IP_CONFIGS
declare -A IP_ADDRESSES
declare -A GATEWAYS
declare -A DNS_SERVERS

# 4. Configure Each Interface (All get 3 options)
for iface in "${INTERFACES[@]}"; do
    echo ""
    log_info "Configuring: $iface"
    echo "Select configuration type for $iface:"
    select opt in "No-IP (Disable)" "Static IP" "DHCP"; do
        case $opt in
            "No-IP (Disable)")
                IP_CONFIGS[$iface]="none"
                log_warn "$iface will be disabled (No-IP)"
                break
                ;;
            "Static IP")
                IP_CONFIGS[$iface]="static"
                read -p "  Enter IP with CIDR (e.g., 192.168.68.69/24): " IP_ADDR
                read -p "  Enter Gateway (e.g., 192.168.68.1): " GW
                read -p "  Enter DNS (comma separated, e.g., 8.8.8.8): " DNS
                IP_ADDRESSES[$iface]=$IP_ADDR
                GATEWAYS[$iface]=$GW
                DNS_SERVERS[$iface]=$DNS
                break
                ;;
            "DHCP")
                IP_CONFIGS[$iface]="dhcp"
                log_info "$iface will use DHCP"
                break
                ;;
            *) echo "Invalid option. Try again.";;
        esac
    done
done

# Helper: Strip CIDR from IP (e.g., 192.168.1.1/24 -> 192.168.1.1)
strip_cidr() { echo "${1%%/*}"; }

# 5. Apply Network Configuration
log_step "Applying Network Configuration"

if [ "$NET_CONFIG_METHOD" == "netplan" ]; then
    # Create backup directory INSIDE /etc/netplan/
    BACKUP_DIR="/etc/netplan/backup_$(date +%F_%H%M)"
    mkdir -p "$BACKUP_DIR"
    log_info "Backup directory: $BACKUP_DIR"
    
    # Backup existing yaml files
    for f in /etc/netplan/*.yaml; do
        [ -e "$f" ] || continue
        fname=$(basename "$f")
        # Skip our own target file if it exists
        if [ "$f" != "/etc/netplan/99-custom-config.yaml" ]; then
            cp "$f" "$BACKUP_DIR/" 2>/dev/null
            log_warn "Backed up: $fname"
        fi
    done

    NETPLAN_FILE="/etc/netplan/99-custom-config.yaml"
    
    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
EOF

    for iface in "${INTERFACES[@]}"; do
        config_type=${IP_CONFIGS[$iface]}
        
        if [ "$config_type" == "none" ]; then
            cat >> "$NETPLAN_FILE" <<EOF
    $iface:
      optional: true
      addresses: []
      dhcp4: false
      dhcp6: false
EOF
        elif [ "$config_type" == "dhcp" ]; then
            cat >> "$NETPLAN_FILE" <<EOF
    $iface:
      dhcp4: true
      optional: true
EOF
        elif [ "$config_type" == "static" ]; then
            DNS_TO_USE=${DNS_SERVERS[$iface]}
            if [ -z "$DNS_TO_USE" ]; then 
                for first_iface in "${INTERFACES[@]}"; do
                    if [ -n "${DNS_SERVERS[$first_iface]}" ]; then
                        DNS_TO_USE=${DNS_SERVERS[$first_iface]}
                        break
                    fi
                done
            fi
            [ -z "$DNS_TO_USE" ] && DNS_TO_USE="8.8.8.8,8.8.4.4"

            cat >> "$NETPLAN_FILE" <<EOF
    $iface:
      addresses: [${IP_ADDRESSES[$iface]}]
      routes:
        - to: default
          via: ${GATEWAYS[$iface]}
      nameservers:
        addresses: [${DNS_TO_USE}]
      optional: true
EOF
        fi
    done

    # Fix Permissions
    chmod 600 "$NETPLAN_FILE"
    chown root:root "$NETPLAN_FILE"
    
    # Validate and Apply (Silent mode for clean output)
    log_info "Validating Netplan configuration..."
    if netplan generate 2>/dev/null; then
        log_info "Configuration valid. Applying..."
        # Apply without --debug flag to avoid noise, suppress stderr for warnings
        if netplan apply 2>&1 | grep -v "DEBUG" | grep -v "WARNING" > /tmp/netplan_log.txt; then
            log_info "Netplan applied successfully."
        else
            # Only show errors if apply actually failed
            if [ $? -ne 0 ]; then
                log_error "Netplan apply failed. Check /tmp/netplan_log.txt"
                cat /tmp/netplan_log.txt
            fi
        fi
    else
        log_error "Netplan generate failed! Check syntax in $NETPLAN_FILE"
        exit 1
    fi

elif [ "$NET_CONFIG_METHOD" == "nmcli" ]; then
    # RHEL/CentOS NetworkManager Logic
    for iface in "${INTERFACES[@]}"; do
        config_type=${IP_CONFIGS[$iface]}
        conn_name="$iface"
        
        if ! nmcli connection show "$conn_name" &> /dev/null; then
            nmcli connection add type ethernet ifname $iface con-name $conn_name > /dev/null 2>&1
        fi

        case $config_type in
            "none")
                nmcli connection modify $conn_name ipv4.method disabled 2>/dev/null
                nmcli connection modify $conn_name ipv6.method ignore 2>/dev/null
                ;;
            "dhcp")
                nmcli connection modify $conn_name ipv4.method auto 2>/dev/null
                nmcli connection modify $conn_name ipv6.method auto 2>/dev/null
                ;;
            "static")
                nmcli connection modify $conn_name ipv4.method manual 2>/dev/null
                nmcli connection modify $conn_name ipv4.addresses ${IP_ADDRESSES[$iface]} 2>/dev/null
                [ -n "${GATEWAYS[$iface]}" ] && nmcli connection modify $conn_name ipv4.gateway ${GATEWAYS[$iface]} 2>/dev/null
                DNS_TO_USE=${DNS_SERVERS[$iface]}
                [ -z "$DNS_TO_USE" ] && DNS_TO_USE="8.8.8.8,8.8.4.4"
                nmcli connection modify $conn_name ipv4.dns "$DNS_TO_USE" 2>/dev/null
                ;;
        esac
        nmcli connection up $conn_name > /dev/null 2>&1
    done
    log_info "NetworkManager configuration applied."
fi

# 6. Hostname & Hosts File (Clean IP Format)
log_step "Configuring Hostname & Hosts"
hostnamectl set-hostname "$HOSTNAME" 2>/dev/null

cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME

# Custom Static IPs
EOF

for iface in "${INTERFACES[@]}"; do
    if [ "${IP_CONFIGS[$iface]}" == "static" ]; then
        CLEAN_IP=$(strip_cidr "${IP_ADDRESSES[$iface]}")
        echo "$CLEAN_IP   $FQDN $HOSTNAME # $iface" >> /etc/hosts
        log_info "Added to hosts: $CLEAN_IP -> $FQDN"
    fi
done

# 7. Install Dependencies
log_step "Installing Dependencies"
if [ "$PKG_MGR" == "apt" ]; then
    apt update -qq > /dev/null 2>&1
    apt install -y python3-dev libffi-dev gcc libssl-dev python3-venv python3-pip net-tools curl wget vim > /dev/null 2>&1
    log_info "Dependencies installed (apt)"
elif [ "$PKG_MGR" == "dnf" ] || [ "$PKG_MGR" == "yum" ]; then
    $PKG_MGR install -y epel-release -q > /dev/null 2>&1
    $PKG_MGR install -y python3-devel libffi-devel gcc openssl-devel python3-pip net-tools curl wget vim -q > /dev/null 2>&1
    log_info "Dependencies installed ($PKG_MGR)"
fi

# 8. Disable Services & Cleanup
log_step "System Optimization"
# Disable Swap
if grep -q "swap" /etc/fstab; then
    swapoff -a 2>/dev/null
    sed -i '/swap/s/^/#/' /etc/fstab
    log_info "Swap disabled."
fi

# Disable Firewall
if systemctl list-unit-files 2>/dev/null | grep -q "$FIREWALL_SERVICE"; then
    systemctl disable --now "$FIREWALL_SERVICE" 2>/dev/null
    log_info "$FIREWALL_SERVICE disabled."
fi

# 9. Final Summary
log_step "Configuration Complete!"
echo "Hostname : $HOSTNAME"
echo "FQDN     : $FQDN"
echo "IPs      :"
for iface in "${INTERFACES[@]}"; do
    echo "  - $iface: ${IP_CONFIGS[$iface]} (${IP_ADDRESSES[$iface]:-N/A})"
done
echo ""
echo "Backup Location: $BACKUP_DIR"
echo "Check network: ip -c a"
echo "Check hosts  : tail -n 5 /etc/hosts"

read -p "Reboot now to apply all changes? (y/n): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    log_info "Rebooting..."
    reboot
else
    log_warn "Please reboot manually later."
fi