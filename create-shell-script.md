### How Create Shell Script
Get IP Address

    hostname --all-ip-addresses | awk '{print $1}'
####
    hostname --all-ip-addresses | awk '{print $2}'

Get IP Address Specefic Interface

    ip -4 -o addr show enp0s8 | awk '{print $4}' | cut -d "/" -f 1
