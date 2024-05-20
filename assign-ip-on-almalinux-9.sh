#!/bin/bash

# Creates a backup
cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak_`date +%Y%m%d%H%M`

read -p "Type static IP Interface Name: " STATIC_INTERFACE
read -p "Type DHCP Interface Name: " DHCP_INTERFACE
read -p "Type static IP Address with CIDR: " IP_ADDRESS
read -p "Type Gateway4: " GATEWAY
read -p "Type DNS: " DNS

cat <<EOF | sudo tee /etc/netplan/00-installer-config.yaml
network:
  renderer: networkd
  ethernets:
    $STATIC_INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADDRESS
      routes: 
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS]
    $DHCP_INTERFACE:
      dhcp4: yes
EOF

# Apply the Netplan configuration
sudo netplan apply
