#!/usr/bin/env bash
set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

# Check if /etc/resolv.conf exists
if [ ! -f /etc/resolv.conf ]; then
    echo "File /etc/resolv.conf does not exist"
fi

# Try to modify the file to test if it's immutable
if touch /etc/resolv.conf 2>/dev/null; then
    echo "File /etc/resolv.conf is not immutable"
else
    echo "File /etc/resolv.conf appears to be immutable"
    echo "Attempting to remove immutable attribute..."
    chattr -i /etc/resolv.conf 2>/dev/null
    
    # Check if we can now modify the file
    if touch /etc/resolv.conf 2>/dev/null; then
        echo "Successfully removed immutable attribute"
    else
        echo "Failed to remove immutable attribute"
        echo "This could be due to other permissions or filesystem limitations"
    fi
fi


echo "=== Installing Unbound ==="
apt update
DEBIAN_FRONTEND=noninteractive apt install -y unbound

echo "=== Setting up Unbound control keys ==="
unbound-control-setup

echo "=== Writing custom Unbound config ==="
CONF_DIR="/etc/unbound"
CONF_FILE="${CONF_DIR}/unbound.conf"
cores=$(
  getconf _NPROCESSORS_ONLN 2>/dev/null \
  || nproc --all 2>/dev/null \
  || grep -c '^processor' /proc/cpuinfo
)

cat > "${CONF_FILE}" <<EOF
server:
    num-threads: ${cores}
    cache-max-ttl: 86400
    cache-min-ttl: 3600
    prefetch: yes
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    so-reuseport: yes
    interface: 127.0.0.1
    port: 53
    access-control: 127.0.0.0/8 allow
    private-address: 192.168.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8

forward-zone:
    name: "."
    forward-first: no
    forward-addr: 8.8.8.8
    forward-addr: 1.1.1.1
EOF

echo "=== Checking Unbound configuration ==="
unbound-checkconf

echo "=== Restarting Unbound ==="
systemctl restart unbound

echo "=== Testing ==="
s=${1:-127.0.0.1}; d=${2:-google.com}
dig @"$s" "$d" +short | grep -q . && echo "DNS OK ✅" || echo "DNS FAIL ❌" 

echo "=== Disabling systemd-resolved ==="
systemctl stop systemd-resolved
systemctl disable systemd-resolved

echo "=== Replacing /etc/resolv.conf ==="
if [ -L /etc/resolv.conf ] || [ -f /etc/resolv.conf ]; then
  rm -f /etc/resolv.conf
fi

cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.1
EOF

echo "=== Locking /etc/resolv.conf ==="
chattr +i /etc/resolv.conf

echo "=== Done! ==="
