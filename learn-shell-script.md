### How Create Shell Script
Get IP Address

    hostname --all-ip-addresses | awk '{print $1}'
####
    hostname --all-ip-addresses | awk '{print $2}'

Get IP Address Specefic Interface

    ip -4 -o addr show enp0s8 | awk '{print $4}' | cut -d "/" -f 1

Get Gateway Address

    ip route | awk 'NR==1 {print $3}'

#!/bin/bash
bgreen='\033[1;32m'
red='\033[0;31m'
nc='\033[0m'
bold="\033[1m"
blink="\033[5m"
echo -e "${bgreen}Adding Compute Node Almalinux with OpenStack ${nc} "
echo
echo
read -p "$(echo -e "${bgreen}${bold}${blink}Type Hostname: ${nc}")" hostname
hostnamectl set-hostname $hostname
ip a

echo -e "${bgreen} Enable PowerTools/CRB repository ${nc} "
dnf install dnf-plugins-core -y
dnf config-manager --set-enabled crb -y
dnf install epel-release -y
dnf install centos-release-openstack-yoga -y
dnf clean all 
yum clean all
yum install network-scripts -y
ls /etc/sysconfig/network-scripts/
systemctl start network
systemctl enable network
systemctl restart network
ip a
echo
echo
echo -e "${bgreen}${bold}${blink} Configuration Static IP for Compute Node ${nc} "
read -p "Type static IP Interface Name: " STATIC_INTERFACE
read -p "Type MAC for static Interface: " MAC_Address
read -p "Type static IP Address: " IP_ADDRESS
read -p "Type IP Address for CIDR: " CIDR
read -p "Type Gateway4: " GATEWAY
read -p "Type 1st DNS: " DNS
read -p "Type 2nd DNS: " DNS2
cat <<EOF | sudo tee /etc/sysconfig/network-scripts/ifcfg-$STATIC_INTERFACE
HWADRR=$MAC_Address
NM_CONTROLLED=no
BOOTPROTO=static
ONBOOT=yes
IPADDR=$IP_ADDRESS/$CIDR
PREFIX=24
GATEWAY=$GATEWAY
DNS1=$DNS
DNS2=$DNS2
DEVICE=$STATIC_INTERFACE
EOF
# Apply the Netplan configuration
nmcli connection up $STATIC_INTERFACE
ip a s $STATIC_INTERFACE
systemctl restart NetworkManager
ifup $STATIC_INTERFACE
cp /etc/sysconfig/network-scripts/ifcfg-$STATIC_INTERFACE /etc/sysconfig/network-scripts/ifcfg-$STATIC_INTERFACE.bak
cat /etc/sysconfig/network-scripts/ifcfg-$STATIC_INTERFACE
echo "$IP_ADDRESS $hostname.paulco.xyz $hostname" >> /etc/hosts
echo
cat /etc/hosts
echo
echo -e "${bgreen}Configuration on OpenStack AllinOne ${nc} "
echo
read -p "Type OpenStack AllinOne Node IP Address: " OCIP_ADDRESS
if ping -c 4 $OCIP_ADDRESS > /dev/null 2>&1;
then
  echo "Ping to $OCIP_ADDRESS was successful."
else
  echo "Ping to $OCIP_ADDRESS failed."
fi
read -p "$(echo -e "${bgreen}${bold}${blink}Type OpenStack AllinOne Node Hostname: ${nc}")" OChostname
echo "$OCIP_ADDRESS $OChostname.paulco.xyz $OChostname" >> /etc/hosts
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
systemctl disable firewalld
systemctl stop firewalld
systemctl disable NetworkManager
systemctl stop NetworkManager
ifup $STATIC_INTERFACE
ip a
yum autoremove epel-release
yum autoremove openstack-packstack
yum clean all
yum repolist
yum update -y && yum upgrade -y


systemctl is-active --quiet iptables && echo iptables is running

#PassWordLess Settings
#!/bin/bash

usernames=("user")

for username in "${usernames[@]}"; do
    home_dir="/home/$username"

    sudo useradd -m -d "$home_dir" -s /bin/bash "$username"

    cd "$home_dir"

    sudo -u "$username" ssh-keygen -t rsa -b 2048 -f "$home_dir/.ssh/id_rsa" -N ""

    sudo -u "$username" cp "$home_dir"/.ssh/id_rsa.pub "$home_dir"/.ssh/authorized_keys

    echo "User '$username' added with home directory '$home_dir'."
done

