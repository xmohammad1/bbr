#!/usr/bin/env bash
set -euo pipefail
chattr -i /etc/resolv.conf
# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
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

cat > "${CONF_FILE}" <<'EOF'
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
    interface: ::1
    port: 53
    access-control: 127.0.0.0/8 allow
    access-control: ::1 allow
    private-address: 192.168.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10

    remote-control:
        control-enable: yes
        control-interface: 127.0.0.1

forward-zone:
    name: "."
    forward-first: no
    forward-addr: 1.1.1.1
    forward-addr: 8.8.8.8
    forward-addr: 2606:4700:4700::1111
    forward-addr: 2001:4860:4860::8888
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
nameserver ::1
EOF

echo "=== Locking /etc/resolv.conf ==="
chattr +i /etc/resolv.conf

echo "=== Done! ==="
