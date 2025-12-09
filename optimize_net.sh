#!/bin/bash

# =================================================================
# Linux Network Interrupt Optimization Script (RPS/RFS)
# =================================================================
# This script automatically detects the interface and CPU count,
# calculates the bitmasks, and sets persistent RPS/RFS values.
# =================================================================

# 1. Check for Root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (sudo ./optimize_net.sh)"
  exit 1
fi

echo "[*] Starting Network Optimization..."

# 2. Detect Primary Interface
# We look for the interface associated with the default route.
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    echo "Error: Could not detect primary network interface."
    exit 1
fi
echo "[+] Detected Interface: $IFACE"

# 3. Detect CPU Cores
CPU_COUNT=$(nproc)
echo "[+] Detected CPU Cores: $CPU_COUNT"

# 4. Calculate RPS CPU Bitmask
# We want to distribute packets to all CPUs.
# Mask = (2^CPU_COUNT) - 1. We calculate this in Hex.
# Example: 4 CPUs = 1111 (binary) = F (hex)
if command -v python3 &>/dev/null; then
    # Python handles large integers better than bash
    RPS_MASK=$(python3 -c "print(hex((1 << $CPU_COUNT) - 1)[2:])")
else
    # Fallback to awk for environments without python
    RPS_MASK=$(awk -v c="$CPU_COUNT" 'BEGIN { mask=0; for(i=0;i<c;i++) mask+=2^i; printf "%x", mask }')
fi

# Ensure mask is valid (sometimes calculation returns 0 on error)
if [ -z "$RPS_MASK" ] || [ "$RPS_MASK" == "0" ]; then
    echo "Error: Failed to calculate CPU mask."
    exit 1
fi
echo "[+] Calculated RPS Bitmask: $RPS_MASK"

# 5. Calculate Flow Entries
# Recommended global value is often 32768 for high traffic
SOCK_FLOW_ENTRIES=32768

# Count RX queues
RX_QUEUES=$(ls -d /sys/class/net/"$IFACE"/queues/rx-* 2>/dev/null | wc -l)

if [ "$RX_QUEUES" -eq 0 ]; then
    echo "Error: No RX queues found for $IFACE. Is the driver loaded?"
    exit 1
fi

# rps_flow_cnt = Global Entries / Number of Queues
FLOW_CNT=$((SOCK_FLOW_ENTRIES / RX_QUEUES))

echo "[+] Detected RX Queues: $RX_QUEUES"
echo "[+] Calculated rps_flow_cnt: $FLOW_CNT"

# =================================================================
# 6. Apply Settings Immediately (Runtime)
# =================================================================

echo "[*] Applying settings to runtime..."

# Set Global Flow Limit
sysctl -w net.core.rps_sock_flow_entries=$SOCK_FLOW_ENTRIES > /dev/null

# Loop through queues and set RPS/RFS
for queue in /sys/class/net/"$IFACE"/queues/rx-*; do
    if [ -w "$queue/rps_cpus" ]; then
        echo "$RPS_MASK" > "$queue/rps_cpus"
    fi
    if [ -w "$queue/rps_flow_cnt" ]; then
        echo "$FLOW_CNT" > "$queue/rps_flow_cnt"
    fi
done

echo "[+] Runtime configuration applied."

# =================================================================
# 7. Create Persistence (Systemd Service)
# =================================================================

SERVICE_PATH="/etc/systemd/system/net-rps-optimize.service"
SCRIPT_PATH="/usr/local/bin/set-net-rps.sh"

echo "[*] Setting up persistence..."

# Generate the executable script for boot time
cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
# Auto-generated network optimization script
sysctl -w net.core.rps_sock_flow_entries=$SOCK_FLOW_ENTRIES
for queue in /sys/class/net/$IFACE/queues/rx-*; do
    echo $RPS_MASK > "\$queue/rps_cpus"
    echo $FLOW_CNT > "\$queue/rps_flow_cnt"
done
EOF

chmod +x "$SCRIPT_PATH"

# Generate Systemd Unit
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Network RPS/RFS Optimization for $IFACE
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload Systemd and Enable
systemctl daemon-reload
systemctl enable net-rps-optimize.service > /dev/null

echo "[+] Systemd service created and enabled: net-rps-optimize.service"
echo "[SUCCESS] Network optimization complete. Settings will persist after reboot."
