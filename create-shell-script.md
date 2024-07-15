### How Create Shell Script
How to find IP Address

    hostname --all-ip-addresses | awk '{print $1}'
####
    hostname --all-ip-addresses | awk '{print $2}'
