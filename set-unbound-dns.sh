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
# Ensure at least 2 cores are used
if [ "$cores" -lt 2 ]; then
  cores=2
  echo "Setting cores to minimum of 2"
else
  echo "Using detected $cores cores"
fi
cat > "${CONF_FILE}" <<EOF
server:
    num-threads: ${cores}
    msg-cache-size: 50m         # Increase message cache to 50 MB
    rrset-cache-size: 100m      # Increase RRset cache to 100 MB
    cache-max-ttl: 86400        # Max cache time: 24 hours
    cache-min-ttl: 3600         # Min cache time: 1 hour
    prefetch: yes               # Pre-fetch records before expiration
    do-ip4: yes                 # Support IPv4
    do-ip6: yes                 # Support IPv6
    do-udp: yes                 # Support UDP
    do-tcp: yes                 # Support TCP
    so-reuseport: yes           # Reuse ports for multi-core efficiency
    so-rcvbuf: 4m               # Socket receive buffer: 4 MB
    so-sndbuf: 4m               # Socket send buffer: 4 MB
    interface: 127.0.0.1        # Listen on localhost
    port: 53                    # Standard DNS port
    access-control: 127.0.0.0/8 allow  # Allow local queries
    private-address: 192.168.0.0/16    # Block private ranges
    private-address: 172.16.0.0/12     # Block private ranges
    private-address: 10.0.0.0/8        # Block private ranges
    serve-expired: yes          # Serve expired records
    serve-expired-ttl: 3600     # Serve expired records for 1 hour post-expiration

forward-zone:
    name: "."                   # Apply to all domains
    forward-first: no           # Always forward to specified servers
    forward-addr: 1.0.0.1       # Cloudflare DNS
    forward-addr: 1.1.1.1       # Cloudflare DNS
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
